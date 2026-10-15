import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences are self-reported. Academic facts remain in TranscriptProvider.
class LearningProfileProvider extends ChangeNotifier {
  static const storageKey = 'flm_learning_profile_v1';

  String? _courseGoal;
  String? _learningStyle;
  String? _studyPriority;
  String? _longTermGoal;
  int? _currentSemester;
  String? _careerGoal;
  bool _isLoaded = false;

  String? get courseGoal => _courseGoal;
  String? get learningStyle => _learningStyle;
  String? get studyPriority => _studyPriority;
  String? get longTermGoal => _longTermGoal;
  int? get currentSemester => _currentSemester;
  String? get careerGoal => _careerGoal;
  bool get isLoaded => _isLoaded;

  Map<String, dynamic> get chatContext => {
    if (_courseGoal != null) 'course_goal': _courseGoal,
    if (_learningStyle != null) 'learning_style': _learningStyle,
    if (_studyPriority != null) 'study_priority': _studyPriority,
    if (_longTermGoal != null) 'long_term_goal': _longTermGoal,
    if (_currentSemester != null) 'current_semester': _currentSemester,
    if (_careerGoal != null) 'career_goal': _careerGoal,
  };

  Future<void> load() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _courseGoal = _valid(data['course_goal'], {'pass', 'high_score'});
        _learningStyle = _valid(data['learning_style'], {
          'practice',
          'reading',
        });
        _studyPriority = _valid(data['study_priority'], {'time', 'depth'});
        _longTermGoal = _valid(data['long_term_goal'], {
          'graduate',
          'career',
          'study_abroad',
        });
        final semester = data['current_semester'];
        _currentSemester = semester is int && semester >= 0 && semester <= 12
            ? semester
            : null;
        _careerGoal = (data['career_goal'] as String?)?.trim();
        if (_careerGoal?.isEmpty ?? false) _careerGoal = null;
      } catch (error) {
        debugPrint('[LearningProfileProvider] Failed to load: $error');
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  static String? _valid(dynamic value, Set<String> allowed) =>
      value is String && allowed.contains(value) ? value : null;

  Future<void> update({
    String? courseGoal,
    String? learningStyle,
    String? studyPriority,
    String? longTermGoal,
    int? currentSemester,
    String? careerGoal,
  }) async {
    _courseGoal = _valid(courseGoal, {'pass', 'high_score'});
    _learningStyle = _valid(learningStyle, {'practice', 'reading'});
    _studyPriority = _valid(studyPriority, {'time', 'depth'});
    _longTermGoal = _valid(longTermGoal, {
      'graduate',
      'career',
      'study_abroad',
    });
    _currentSemester =
        currentSemester != null && currentSemester >= 0 && currentSemester <= 12
        ? currentSemester
        : null;
    _careerGoal = careerGoal?.trim();
    if (_careerGoal?.isEmpty ?? false) _careerGoal = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(chatContext));
    notifyListeners();
  }
}
