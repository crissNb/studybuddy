import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  double _volume = 0.8;
  String _soundFile = 'alarm.ogg';
  late SharedPreferences _prefs;

  SettingsProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  double get volume => _volume;
  String get soundFile => _soundFile;

  Future<void> _loadSettings() async {
    _volume = _prefs.getDouble('volume') ?? 0.8;
    _soundFile = _prefs.getString('soundFile') ?? 'alarm.ogg';
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _prefs.setDouble('volume', volume);
    notifyListeners();
  }

  Future<void> setSoundFile(String soundFile) async {
    _soundFile = soundFile;
    await _prefs.setString('soundFile', soundFile);
    notifyListeners();
  }
}
