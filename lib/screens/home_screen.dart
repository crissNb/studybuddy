import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/esense_provider.dart';
import 'settings_screen.dart';
import '../providers/analysis_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showHowTo = false;

  Widget _buildStatsCard() {
    return Consumer<AnalysisProvider>(
      builder: (context, analysisProvider, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Study Performance',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(
                    'Total Score: ${analysisProvider.totalScore.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: analysisProvider.totalScore >= 0
                          ? Colors.green
                          : Colors.red,
                    )),
                const SizedBox(height: 8),
                Text('Total Sessions: ${analysisProvider.sessionsCount}'),
                if (analysisProvider.lastSessionMetrics.isNotEmpty) ...[
                  const Divider(),
                  const Text('Last Session Analysis:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      'Movement Score: ${analysisProvider.lastSessionMetrics['movementScore']?.toStringAsFixed(1) ?? '0.0'}'),
                  Text(
                      'Stability Score: ${analysisProvider.lastSessionMetrics['stabilityScore']?.toStringAsFixed(1) ?? '0.0'}'),
                  const SizedBox(height: 8),
                  Text(
                      'Head Movement: ${(analysisProvider.lastSessionMetrics['avgMovement'] ?? 0 * 100).toStringAsFixed(1)}%'),
                  Text(
                      'Head Rotation: ${(analysisProvider.lastSessionMetrics['avgRotation'] ?? 0 * 100).toStringAsFixed(1)}%'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHowToCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('How to use StudyBuddy'),
        initiallyExpanded: _showHowTo,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('1. Connect your eSense earbuds',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Make sure your earbuds are charged and nearby.'),
                SizedBox(height: 8),
                Text('2. Calibrate your position',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Sit straight and look forward during calibration.'),
                SizedBox(height: 8),
                Text('3. Start studying',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    'StudyBuddy will monitor your posture and alert you when needed.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildESenseInput() {
    return Consumer<ESenseProvider>(
      builder: (context, eSenseProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'eSense Device Number',
              hintText: 'Enter your eSense number (default: 0320)',
            ),
            // Initialize with current value
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: eSenseProvider.deviceNumber,
                selection: TextSelection.collapsed(
                  offset: eSenseProvider.deviceNumber.length,
                ),
              ),
            ),
            onChanged: (value) {
              // Only update if input contains digits
              if (value.contains(RegExp(r'^[0-9]*$'))) {
                eSenseProvider.updateDeviceNumber(value);
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyBuddy',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Consumer<ESenseProvider>(
        builder: (context, eSenseProvider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHowToCard(),
                _buildStatsCard(),
                _buildESenseInput(),
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (!eSenseProvider.isConnected) ...[
                          const Icon(Icons.headphones_outlined, size: 48),
                          if (eSenseProvider.connectionError != null)
                            Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Error: ${eSenseProvider.connectionError}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          Text('eSense-${eSenseProvider.deviceNumber}',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            eSenseProvider.isConnecting
                                ? 'Attempting to connect...'
                                : 'Ready to connect',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => eSenseProvider.connectToESense(),
                            icon: const Icon(Icons.bluetooth),
                            label: Text(eSenseProvider.isConnecting
                                ? 'Connecting...'
                                : 'Connect to eSense'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                        ] else ...[
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 48),
                          const Text('Connected to eSense!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              )),
                          Text(
                            'Connected since:\n${eSenseProvider.connectedAt?.toString().split('.')[0] ?? "Unknown"}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          if (!eSenseProvider.isCalibrated) ...[
                            if (eSenseProvider.isCalibrating) ...[
                              CircularProgressIndicator(
                                value: eSenseProvider.calibrationCountdown / 10,
                              ),
                              const SizedBox(height: 16),
                              if (eSenseProvider.calibrationCountdown > 5)
                                Text(
                                  'Get ready! Starting in ${eSenseProvider.calibrationCountdown - 5}',
                                  textAlign: TextAlign.center,
                                )
                              else
                                Column(
                                  children: [
                                    const Icon(Icons.straight, size: 32),
                                    const Text('Keep your head straight!',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        'Calibrating: ${eSenseProvider.calibrationCountdown}'),
                                  ],
                                ),
                            ] else ...[
                              const Text('Calibration Required',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    eSenseProvider.startCalibration(),
                                icon: const Icon(Icons.loop),
                                label: const Text('Start Calibration'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ] else ...[
                            const Icon(Icons.school,
                                size: 48, color: Colors.blue),
                            const Text(
                              'Ready to Study!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => eSenseProvider.disconnect(),
                            icon: const Icon(Icons.power_settings_new),
                            label: const Text('Stop Studying'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
