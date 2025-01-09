import 'dart:math' as Math;

class SensorDataHandler {
  // Filtering coefficients
  static const double _alpha = 0.96;
  static const double _lowPassAlpha = 0.8;

  double _pitch = 0.0;
  double _roll = 0.0;
  double _yaw = 0.0;

  double _pitchOffset = 0.0;
  double _rollOffset = 0.0;
  double _yawOffset = 0.0;

  double _filteredAx = 0.0;
  double _filteredAy = 0.0;
  double _filteredAz = 0.0;
  double _filteredGx = 0.0;
  double _filteredGy = 0.0;
  double _filteredGz = 0.0;

  double _lastTimestamp = 0.0;

  int _calibrationCount = 0;
  double _sumPitchForCalib = 0.0;
  double _sumRollForCalib = 0.0;
  double _sumYawForCalib = 0.0;

  /// Processes incoming raw accelerometer (accel) and gyroscope (gyro) data.
  /// [accel] and [gyro] are assumed to be lists of size 3 containing integer readings.
  /// Call this on each new data sample to update orientation and acceleration.
  void updateData(List<int>? accel, List<int>? gyro) {
    if (accel == null || gyro == null) return;

    final currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (_lastTimestamp == 0.0) {
      // First-time initialization
      _lastTimestamp = currentTime;
      _lowPassInitialize(accel, gyro);
      return;
    }

    // Calculate delta time
    final double dt = currentTime - _lastTimestamp;
    _lastTimestamp = currentTime;

    // Low pass filter for accelerometer and gyroscope
    _filteredAx = _lowPassAlpha * _filteredAx + (1 - _lowPassAlpha) * accel[0];
    _filteredAy = _lowPassAlpha * _filteredAy + (1 - _lowPassAlpha) * accel[1];
    _filteredAz = _lowPassAlpha * _filteredAz + (1 - _lowPassAlpha) * accel[2];

    _filteredGx = _lowPassAlpha * _filteredGx + (1 - _lowPassAlpha) * gyro[0];
    _filteredGy = _lowPassAlpha * _filteredGy + (1 - _lowPassAlpha) * gyro[1];
    _filteredGz = _lowPassAlpha * _filteredGz + (1 - _lowPassAlpha) * gyro[2];

    // Integration of gyroscope data
    final double gxDeg = _filteredGx / 10000.0;
    final double gyDeg = _filteredGy / 10000.0;
    final double gzDeg = _filteredGz / 10000.0;

    final double deltaPitch = gxDeg * dt;
    final double deltaRoll = gyDeg * dt;
    final double deltaYaw = gzDeg * dt;

    // Update angles from gyroscope
    _pitch += deltaPitch;
    _roll += deltaRoll;
    _yaw += deltaYaw;

    // Normalize angles to -180 to 180 degrees
    _pitch = _normalizeAngle(_pitch);
    _roll = _normalizeAngle(_roll);
    _yaw = _normalizeAngle(_yaw);

    // Accelerometer
    final double ax = _filteredAx / 10000.0;
    final double ay = _filteredAy / 10000.0;
    final double az = _filteredAz / 10000.0;

    // Pitch and roll from accelerometer
    final double accPitch =
        _toDegrees(Math.atan2(ay, Math.sqrt(ax * ax + az * az)));
    final double accRoll = _toDegrees(Math.atan2(-ax, az));

    // Complementary filter for gyroscope to avoid drift
    _pitch = _alpha * _pitch + (1 - _alpha) * accPitch;
    _roll = _alpha * _roll + (1 - _alpha) * accRoll;

    // Normalize angles to -180 to 180 degrees
    _pitch = _normalizeAngle(_pitch);
    _roll = _normalizeAngle(_roll);
    _yaw = _normalizeAngle(_yaw);
  }

  /// Calibrate orientation and acceleration based on current data.
  /// Each call accumulates values to compute an average offset when you decide calibration is complete.
  void calibrate(List<int>? accel, List<int>? gyro) {
    if (accel == null || gyro == null) return;

    final double ax = accel[0] / 10000.0;
    final double ay = accel[1] / 10000.0;
    final double az = accel[2] / 10000.0;

    final double accPitch =
        _toDegrees(Math.atan2(ay, Math.sqrt(ax * ax + az * az)));
    final double accRoll = _toDegrees(Math.atan2(-ax, az));

    final double gzDeg = gyro[2] / 10000.0;

    _calibrationCount++;
    _sumPitchForCalib += accPitch;
    _sumRollForCalib += accRoll;
    _sumYawForCalib += gzDeg;
  }

  /// Completes the calibration and sets the current orientation/acceleration offsets so that
  /// the system reads (0,0,0) for pitch, roll, yaw when no movement is happening.
  void finalizeCalibration() {
    if (_calibrationCount == 0) return;

    final double avgPitch = _sumPitchForCalib / _calibrationCount;
    final double avgRoll = _sumRollForCalib / _calibrationCount;
    final double avgYaw = _sumYawForCalib / _calibrationCount;

    // We set our orientation offsets so that the average becomes zero
    _pitchOffset = avgPitch;
    _rollOffset = avgRoll;
    _yawOffset = avgYaw;

    _calibrationCount = 0;
    _sumPitchForCalib = 0.0;
    _sumRollForCalib = 0.0;
    _sumYawForCalib = 0.0;
  }

  /// Resets calibration counters and offsets to zero.
  void resetCalibration() {
    _pitchOffset = 0.0;
    _rollOffset = 0.0;
    _yawOffset = 0.0;
    _calibrationCount = 0;
    _sumPitchForCalib = 0.0;
    _sumRollForCalib = 0.0;
    _sumYawForCalib = 0.0;
  }

  /// Returns the current pitch, roll, yaw angles (in degrees),
  /// subtracted by the calibration offsets (so after calibrate they read ~0 if stationary).
  double get pitch => _normalizeAngle(_pitch - _pitchOffset);
  double get roll => _normalizeAngle(_roll - _rollOffset);
  double get yaw => _normalizeAngle(_yaw - _yawOffset);

  /// Calculates a "forward/up/left-right" acceleration in a stable axis
  /// based on the calibrated orientation. This helps keep X, Y, Z recognition consistent
  /// (e.g., forward => Z, up => Y, left/right => X).
  List<double> get stableAcceleration {
    final double ax = _filteredAx / 10000.0;
    final double ay = _filteredAy / 10000.0;
    final double az = _filteredAz / 10000.0;

    final double pRad = _degToRad(pitch);
    final double rRad = _degToRad(roll);
    final double yRad = _degToRad(yaw);

    final List<double> rotated = _rotateXYZ(ax, ay, az, pRad, rRad, yRad);

    return rotated;
  }

  void _lowPassInitialize(List<int> accel, List<int> gyro) {
    _filteredAx = accel[0].toDouble();
    _filteredAy = accel[1].toDouble();
    _filteredAz = accel[2].toDouble();
    _filteredGx = gyro[0].toDouble();
    _filteredGy = gyro[1].toDouble();
    _filteredGz = gyro[2].toDouble();
  }

  List<double> _rotateXYZ(double x, double y, double z, double pitchRad,
      double rollRad, double yawRad) {
    // Rotation about X (roll), Y (pitch), Z (yaw)
    final double cosX = Math.cos(rollRad);
    final double sinX = Math.sin(rollRad);
    final double cosY = Math.cos(pitchRad);
    final double sinY = Math.sin(pitchRad);
    final double cosZ = Math.cos(yawRad);
    final double sinZ = Math.sin(yawRad);

    // Rotate around X
    double ry = y * cosX - z * sinX;
    double rz = y * sinX + z * cosX;
    double rx = x;

    // Rotate around Y
    double rz2 = rz * cosY - rx * sinY;
    double rx2 = rz * sinY + rx * cosY;
    double ry2 = ry;

    // Rotate around Z
    double rx3 = rx2 * cosZ - ry2 * sinZ;
    double ry3 = rx2 * sinZ + ry2 * cosZ;
    double rz3 = rz2;

    return [rx3, ry3, rz3];
  }

  double _normalizeAngle(double angle) {
    double modAngle = angle % 360.0;
    if (modAngle > 180.0) {
      modAngle -= 360.0;
    } else if (modAngle < -180.0) {
      modAngle += 360.0;
    }
    return modAngle;
  }

  double _toDegrees(double radians) => radians * 180.0 / Math.pi;
  double _degToRad(double deg) => deg * Math.pi / 180.0;
}
