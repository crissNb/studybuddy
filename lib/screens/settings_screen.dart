import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Volume', style: Theme.of(context).textTheme.titleLarge),
                Slider(
                  value: settings.volume,
                  onChanged: (value) => settings.setVolume(value),
                ),
                const SizedBox(height: 20),
                Text('Alert Sound',
                    style: Theme.of(context).textTheme.titleLarge),
                DropdownButton<String>(
                  value: settings.soundFile,
                  items: const [
                    DropdownMenuItem(value: 'alarm.ogg', child: Text('alarm')),
                    DropdownMenuItem(
                        value: 'alarm2.ogg', child: Text('alarm2')),
                    DropdownMenuItem(
                        value: 'durchgefallen.wav',
                        child: Text('durchgefallen')),
                    DropdownMenuItem(
                        value: 'iphone.wav', child: Text('iphone')),
                  ],
                  onChanged: (value) => settings.setSoundFile(value!),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
