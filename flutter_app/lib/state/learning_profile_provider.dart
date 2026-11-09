import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/personal_preferences.dart';
import '../data/personal_data_repository.dart';
import '../models/load_status.dart';

/// Preferences are self-reported. Academic facts remain in TranscriptProvider.
class LearningProfileProvider extends ChangeNotifier {
  LearningProfileProvider({PersonalPreferences? storage, this.repository})
    : _storage = storage ?? PersonalPreferences();
  final PersonalPreferences _storage;
  final PersonalDataRepository? repository;
  static const storageKey = 'flm_learning_profile_v1';
  Map<String, dynamic> _data = {};
  bool _isLoaded = false;
  bool _disposed = false;
  bool saving = false;
  String? error;
  LoadStatus status = LoadStatus.loading;
  bool get usesCloud => repository != null;
  String? get courseGoal => _data['course_goal'] as String?;
  String? get learningStyle => _data['learning_style'] as String?;
  String? get studyPriority => _data['study_priority'] as String?;
  String? get longTermGoal => _data['long_term_goal'] as String?;
  int? get currentSemester => _data['current_semester'] as int?;
  String? get careerGoal => _data['career_goal'] as String?;
  bool get isLoaded => _isLoaded;
  Map<String, dynamic> get chatContext => Map.unmodifiable(_data);

  Future<void> load({bool retry = false}) async {
    if (_isLoaded && !retry) return;
    status = LoadStatus.loading;
    error = null;
    _notify();
    try {
      Map<String, dynamic>? data;
      if (repository != null) {
        data = await repository!.loadProfile();
      } else {
        final prefs = await _storage.open();
        final raw = prefs.getString(storageKey);
        if (raw != null) data = jsonDecode(raw) as Map<String, dynamic>;
      }
      if (_disposed) return;
      _data = _validated(data ?? {});
      _isLoaded = true;
      status = _data.isEmpty ? LoadStatus.empty : LoadStatus.data;
    } catch (_) {
      status = LoadStatus.error;
      error = 'Không thể tải hồ sơ. Kiểm tra kết nối và thử lại.';
    }
    _notify();
  }

  static Map<String, dynamic> _validated(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    final allowed = {
      'course_goal': {'pass', 'high_score'},
      'learning_style': {'practice', 'reading'},
      'study_priority': {'time', 'depth'},
      'long_term_goal': {'graduate', 'career', 'study_abroad'},
    };
    for (final field in allowed.entries) {
      if (field.value.contains(data[field.key])) {
        result[field.key] = data[field.key];
      }
    }
    final semester = data['current_semester'];
    if (semester is int && semester >= 0 && semester <= 12) {
      result['current_semester'] = semester;
    }
    final career = data['career_goal'];
    if (career is String && career.trim().isNotEmpty) {
      result['career_goal'] = career.trim().substring(
        0,
        career.trim().length.clamp(0, 80),
      );
    }
    return result;
  }

  Future<void> update({
    String? courseGoal,
    String? learningStyle,
    String? studyPriority,
    String? longTermGoal,
    int? currentSemester,
    String? careerGoal,
  }) async {
    if (saving) return;
    final next = _validated({
      'course_goal': courseGoal,
      'learning_style': learningStyle,
      'study_priority': studyPriority,
      'long_term_goal': longTermGoal,
      'current_semester': currentSemester,
      'career_goal': careerGoal,
    });
    saving = true;
    error = null;
    _notify();
    try {
      if (repository != null) {
        await repository!.saveProfile(next);
      } else {
        final prefs = await _storage.open();
        if (!await prefs.setString(storageKey, jsonEncode(next))) {
          throw StateError('Cannot save profile.');
        }
      }
      if (_disposed) return;
      _data = next;
      _isLoaded = true;
      status = _data.isEmpty ? LoadStatus.empty : LoadStatus.data;
    } catch (_) {
      error = 'Không thể lưu hồ sơ. Kiểm tra kết nối và thử lại.';
      rethrow;
    } finally {
      saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
