import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:esense_flutter/esense.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:studybuddy/models/sensor_data_handler.dart';
import 'package:studybuddy/providers/analysis_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'settings_provider.dart';

class ESenseProvider with ChangeNotifier {
  // Max number of sensor data points to keep in memory
  static const int SAMPLE_DATA_SIZE = 20;

  // Sleep detection
  static const double SLEEP_ACCEL_THRESHOLD = 0.015;
  static const int SLEEP_GYRO_THRESHOLD = 120;
  static const int SLEEP_BREAKOUT_GYRO_THRESHOLD = 30;

  static const String DEVICE_NUMBER_KEY = 'esense_device_number';
  String _deviceNumber = '0320';

  String get deviceNumber => _deviceNumber;

  ESenseProvider() {
    _loadDeviceNumber();
  }

  Future<void> _loadDeviceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceNumber = prefs.getString(DEVICE_NUMBER_KEY) ?? '0320';
    notifyListeners();
  }

  Future<void> updateDeviceNumber(String number) async {
    _deviceNumber = number;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(DEVICE_NUMBER_KEY, number);
    notifyListeners();
  }

  ESenseManager? eSenseManager;

  // Connections
  bool isConnected = false;
  bool isConnecting = false;
  String? connectionError;
  DateTime? connectedAt;
  String? deviceName;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  DateTime? _lastAlertTime;
  static const int MIN_ALERT_INTERVAL = 3; // Minimum seconds between alerts

  SensorDataHandler sensorDataHandler = SensorDataHandler();

  // calibration
  bool isCalibrated = false;
  bool isCalibrating = false;
  int calibrationCountdown = 10; // 5s prep + 5s callibration
  Timer? calibrationTimer;
  bool sleepDetected = false;

  // Sensor data
  final Queue<List<double>> _accelData = Queue();
  final Queue<List<double>> _gyroData = Queue();

  // Study session data
  final List<List<double>> _studyDeltaAccelData = [];
  final List<List<double>> _studyGyroData = [];

  StreamSubscription? _sensorSubscription;

  Future<void> _askForPermissions() async {
    if (Platform.isAndroid) {
      if (!(await Permission.bluetoothScan.request().isGranted &&
          await Permission.bluetoothConnect.request().isGranted)) {
        print(
            'WARNING - no permission to use Bluetooth granted (Android). Cannot access eSense device.');
      }

      if (!(await Permission.locationWhenInUse.request().isGranted)) {
        print(
            'WARNING - no permission to access location granted. Cannot access eSense device.');
      }
    } else if (Platform.isIOS) {
      // Permissionhandler plugin works differently on iOS, for bluetoothScan and bluetoothConnect permissions,
      // iOS always returns notGranted, so we need to check the permission differently.
      if (!(await Permission.bluetooth.request().isGranted)) {
        print(
            'WARNING - no permission to use Bluetooth granted (iOS). Cannot access eSense device.');
      }
    }
  }

  Future<void> connectToESense([String? customNumber]) async {
    try {
      connectionError = null;
      isConnecting = true;
      // Use custom number or stored device number
      deviceName = 'eSense-${customNumber ?? _deviceNumber}';
      notifyListeners();

      // check connected bluetooth devices to get esense device name
      await _askForPermissions();

      eSenseManager = ESenseManager(deviceName!);

      // Listen to connection events
      eSenseManager!.connectionEvents.listen((event) {
        if (event.type == ConnectionType.connected) {
          isConnected = true;
          isConnecting = false;
          connectedAt = DateTime.now();

          _startListenToSensorEvents();
        } else if (event.type == ConnectionType.disconnected) {
          isConnected = false;
          connectedAt = null;
        }
        notifyListeners();
      });

      // Start connecting
      await eSenseManager!.connect();
    } catch (e) {
      connectionError = e.toString();
      isConnecting = false;
      notifyListeners();
    }
  }

  void _startListenToSensorEvents() {
    // Cancel any existing subscription
    _sensorSubscription?.cancel();

    // Read sensor data
    _sensorSubscription = eSenseManager?.sensorEvents.listen((event) {
      List<int>? accel = event.accel;
      List<int>? gyro = event.gyro;

      if (isCalibrated) {
        // Calculate the movement vector
        sensorDataHandler.updateData(accel, gyro);
      } else if (isCalibrating && calibrationCountdown <= 5) {
        sensorDataHandler.calibrate(accel, gyro);
      }

      // Keep track of sensor data
      if (_accelData.length >= SAMPLE_DATA_SIZE &&
          _gyroData.length >= SAMPLE_DATA_SIZE) {
        _decideHeadTilt();
        _accelData.clear();
        _gyroData.clear();
      }

      _accelData.add(sensorDataHandler.stableAcceleration);
      List<double> newGyroData = [
        sensorDataHandler.pitch,
        sensorDataHandler.roll,
        sensorDataHandler.yaw
      ];
      _gyroData.add(newGyroData);

      notifyListeners();
    });
  }

  void _decideHeadTilt() {
    // Calculate delta accelerations
    List<double> lastAccel = _accelData.first;
    List<double> avgDeltaAccel = [0, 0, 0];

    for (int i = 1; i < _accelData.length; i++) {
      List<double> accel = _accelData.elementAt(i);
      List<double> deltaAccel = [
        accel[0] - lastAccel[0],
        accel[1] - lastAccel[1],
        accel[2] - lastAccel[2]
      ];

      avgDeltaAccel[0] += deltaAccel[0];
      avgDeltaAccel[1] += deltaAccel[1];
      avgDeltaAccel[2] += deltaAccel[2];
      lastAccel = accel;
    }

    // Calculate the average delta acceleration
    avgDeltaAccel[0] /= _accelData.length;
    avgDeltaAccel[1] /= _accelData.length;
    avgDeltaAccel[2] /= _accelData.length;

    // Calculate average pitch and roll and yaw angles
    List<double> avgGyro = [0, 0, 0];

    for (int i = 0; i < _gyroData.length; i++) {
      List<double> gyro = _gyroData.elementAt(i);
      avgGyro[0] += gyro[0];
      avgGyro[1] += gyro[1];
      avgGyro[2] += gyro[2];
    }

    avgGyro[0] /= _gyroData.length;
    avgGyro[1] /= _gyroData.length;
    avgGyro[2] /= _gyroData.length;

    _studyDeltaAccelData.add(avgDeltaAccel);
    _studyGyroData.add(avgGyro);

    if (sleepDetected &&
        avgGyro[0].abs() + avgGyro[1].abs() + avgGyro[2].abs() <
            SLEEP_BREAKOUT_GYRO_THRESHOLD) {
      sleepDetected = false;
    }

    if (avgDeltaAccel[0] > SLEEP_ACCEL_THRESHOLD &&
            avgDeltaAccel[1] > SLEEP_ACCEL_THRESHOLD ||
        avgGyro[1].abs() > SLEEP_GYRO_THRESHOLD ||
        sleepDetected) {
      _onHeadTiltDetected();
      sleepDetected = true;
    }
  }

  Future<void> _onHeadTiltDetected() async {
    // Check if enough time has passed since the last alert
    if (_lastAlertTime != null) {
      int secondsSinceLastAlert =
          DateTime.now().difference(_lastAlertTime!).inSeconds;
      if (secondsSinceLastAlert < MIN_ALERT_INTERVAL) {
        return; // Skip if alerts are too frequent
      }
    }

    try {
      // Get current settings
      final settings = Provider.of<SettingsProvider>(
          navigatorKey.currentContext!,
          listen: false);

      // Set the volume
      await _audioPlayer.setVolume(settings.volume);

      // Play the selected sound
      await _audioPlayer.play(AssetSource('sounds/${settings.soundFile}'));

      // Update last alert time
      _lastAlertTime = DateTime.now();

      debugPrint(
          'Alert sound played: ${settings.soundFile} at volume ${settings.volume}');
    } catch (e) {
      debugPrint('Error playing alert sound: $e');
    }
  }

  Future<void> startCalibration() async {
    isCalibrating = true;
    isCalibrated = false;
    calibrationCountdown = 10;

    calibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      calibrationCountdown--;
      if (calibrationCountdown <= 0) {
        _finishCalibration();
        timer.cancel();
      }
      notifyListeners();
    });

    notifyListeners();
  }

  void _finishCalibration() {
    isCalibrating = false;
    isCalibrated = true;
    calibrationTimer?.cancel();
    sensorDataHandler.finalizeCalibration();
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (isCalibrated && _studyDeltaAccelData.isNotEmpty) {
      await endStudySession();
    }

    // Disconnect from device
    _sensorSubscription?.cancel();
    await eSenseManager?.disconnect();
    // Clear all data
    _accelData.clear();
    _gyroData.clear();
    _studyDeltaAccelData.clear();
    _studyGyroData.clear();

    // Reset sensor data handler
    sensorDataHandler = SensorDataHandler();

    // Reset all state flags
    isCalibrated = false;
    isCalibrating = false;
    isConnected = false;
    isConnecting = false;
    sleepDetected = false;

    // Clear timers and timestamps
    calibrationTimer?.cancel();
    connectedAt = null;
    _lastAlertTime = null;
    connectionError = null;

    // Clean up manager instance
    eSenseManager = null;

    notifyListeners();
  }

  Future<void> endStudySession() async {
    if (_studyDeltaAccelData.isEmpty || _studyGyroData.isEmpty) return;

    final analysisProvider = Provider.of<AnalysisProvider>(
        navigatorKey.currentContext!,
        listen: false);

    Map<String, double> metrics = await analysisProvider.analyzeStudySession(
        _studyDeltaAccelData, _studyGyroData);

    // Clear session data
    _studyDeltaAccelData.clear();
    _studyGyroData.clear();

    // Show score dialog
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Study Session Analysis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Score: ${metrics['totalScore']?.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: (metrics['totalScore'] ?? 0) >= 0
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              const Divider(),
              const Text('Detailed Analysis:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'Movement Score: ${metrics['movementScore']?.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: (metrics['movementScore'] ?? 0) >= 0
                        ? Colors.green
                        : Colors.red,
                  )),
              Text(
                  'Stability Score: ${metrics['stabilityScore']?.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: (metrics['stabilityScore'] ?? 0) >= 0
                        ? Colors.green
                        : Colors.red,
                  )),
              const SizedBox(height: 8),
              Text(
                  'Head Movement: ${(metrics['avgMovement'] ?? 0 * 100).toStringAsFixed(1)}%'),
              Text(
                  'Head Rotation: ${(metrics['avgRotation'] ?? 0 * 100).toStringAsFixed(1)}%'),
              const Divider(),
              Text(
                'Feedback: ${_getFeedback(metrics)}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getFeedback(Map<String, double> metrics) {
    double totalScore = metrics['totalScore'] ?? 0;
    if (totalScore >= 0) {
      return 'Great job staying focused and maintaining good posture!';
    } else if (totalScore >= -50) {
      return 'Try to maintain a more stable position while studying.';
    } else {
      return 'Consider taking a break and adjusting your study position.';
    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _audioPlayer.dispose();
    eSenseManager?.disconnect();
    super.dispose();
  }
}
