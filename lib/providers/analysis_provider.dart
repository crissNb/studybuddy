import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisProvider with ChangeNotifier {
  static const String TOTAL_SCORE_KEY = 'total_study_score';
  static const String SESSIONS_COUNT_KEY = 'study_sessions_count';

  double _totalScore = 0;
  int _sessionsCount = 0;
  Map<String, double> _lastSessionMetrics = {};

  AnalysisProvider() {
    _loadScores();
  }

  double get averageScore =>
      _sessionsCount > 0 ? _totalScore / _sessionsCount : 0;
  double get totalScore => _totalScore;
  int get sessionsCount => _sessionsCount;
  Map<String, double> get lastSessionMetrics => _lastSessionMetrics;

  Future<void> _loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    _totalScore = prefs.getDouble(TOTAL_SCORE_KEY) ?? 0;
    _sessionsCount = prefs.getInt(SESSIONS_COUNT_KEY) ?? 0;
    notifyListeners();
  }

  Future<void> _saveScores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(TOTAL_SCORE_KEY, _totalScore);
    await prefs.setInt(SESSIONS_COUNT_KEY, _sessionsCount);
  }

  Future<Map<String, double>> analyzeStudySession(
      List<List<double>> deltaAccelData, List<List<double>> gyroData) async {
    if (deltaAccelData.isEmpty || gyroData.isEmpty) {
      return {'totalScore': 0};
    }

    // Movement analysis (negative score for more movement)
    double avgMovement = _calculateAvgMovement(deltaAccelData);
    double movementScore = -100 * (avgMovement / 0.05);

    // Head stability analysis
    double avgRotation = _calculateAvgRotation(gyroData);
    double stabilityScore = -100 * (avgRotation / 200);

    // Combine scores
    double sessionScore = (movementScore + stabilityScore) / 2;

    // Update metrics
    _lastSessionMetrics = {
      'movementScore': movementScore,
      'stabilityScore': stabilityScore,
      'avgMovement': avgMovement,
      'avgRotation': avgRotation,
      'totalScore': sessionScore
    };

    // Update total score
    _totalScore += sessionScore;
    _sessionsCount++;
    await _saveScores();
    notifyListeners();

    return _lastSessionMetrics;
  }

  double _calculateAvgMovement(List<List<double>> deltaAccelData) {
    double totalMovement = deltaAccelData.fold(0, (sum, accel) {
      return sum +
          sqrt(accel[0] * accel[0] + accel[1] * accel[1] + accel[2] * accel[2]);
    });
    return totalMovement / deltaAccelData.length;
  }

  double _calculateAvgRotation(List<List<double>> gyroData) {
    double totalRotation = gyroData.fold(0, (sum, gyro) {
      return sum + gyro.map((e) => e.abs()).reduce((a, b) => a + b);
    });
    return totalRotation / gyroData.length;
  }
}
