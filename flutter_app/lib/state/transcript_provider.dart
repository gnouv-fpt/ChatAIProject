import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transcript_entry.dart';
import '../services/grade_calculator.dart';

/// Provider toàn cục lưu transcript & GPA của sinh viên (local, không lên server).
/// Tuân thủ Mục 8.2: bảng điểm lưu local, không lưu ảnh, không đưa vào RAG chung.
class TranscriptProvider extends ChangeNotifier {
  static const _storageKey = 'flm_transcript_v1';
  static const _customStatusKey = 'flm_course_custom_status_v1';

  List<TranscriptEntry> _entries = [];
  Map<String, String> _customStatusMap = <String, String>{}; // courseCode -> 'passed' | 'retake' | 'in_progress' | 'not_started'
  double _targetGpa = 8.0;
  bool _isLoaded = false;

  List<TranscriptEntry> get entries => List.unmodifiable(_entries);
  Map<String, String> get customStatusMap => Map.unmodifiable(_customStatusMap);
  double get targetGpa => _targetGpa;
  bool get hasTranscript => _entries.isNotEmpty;
  bool get isLoaded => _isLoaded;

  /// Lấy trạng thái học tập của môn học (kết hợp bảng điểm và tuỳ chỉnh thủ công của sinh viên)
  /// Trả về: 'passed' | 'retake' | 'in_progress' | 'not_started'
  String getCourseStatus(String courseCode) {
    if (courseCode.isEmpty) return 'not_started';
    final normCode = GradeCalculator.normalizeCode(courseCode);
    final map = _customStatusMap;
    if (map.isNotEmpty && map.containsKey(normCode)) {
      return map[normCode] ?? 'not_started';
    }
    // Tìm trong bảng điểm OCR nếu có
    if (_entries.isNotEmpty) {
      for (final e in _entries) {
        if (GradeCalculator.normalizeCode(e.courseCode) == normCode) {
          return e.isPassed ? 'passed' : 'retake';
        }
      }
    }
    return 'not_started';
  }

  /// Đặt trạng thái học tập của môn học
  Future<void> setCourseStatus(String courseCode, String status) async {
    final normCode = GradeCalculator.normalizeCode(courseCode);
    if (status == 'not_started') {
      _customStatusMap.remove(normCode);
    } else {
      _customStatusMap[normCode] = status;
    }
    notifyListeners();
    await _persistCustomStatus();
  }

  /// Chuyển đổi nhanh giữa 'passed' (đã hoàn thành) và 'not_started' (chưa học)
  Future<void> toggleCoursePassed(String courseCode) async {
    final current = getCourseStatus(courseCode);
    if (current == 'passed') {
      await setCourseStatus(courseCode, 'not_started');
    } else {
      await setCourseStatus(courseCode, 'passed');
    }
  }

  /// Kết quả tính GPA (lazy, tái tính khi entries thay đổi)
  GradeEvaluationResult? _cachedResult;

  GradeEvaluationResult get evaluation {
    _cachedResult ??= GradeCalculator.evaluateTranscript(_entries);
    return _cachedResult!;
  }

  /// Điểm cần đạt cho mục tiêu GPA với N tín chỉ còn lại
  Map<String, dynamic> requiredGpaFor(int remainingGpaCredits) {
    final eval = evaluation;
    return GradeCalculator.calculateRequiredGpa(
      currentWeightedScore: eval.currentGpa * eval.totalGpaCredits,
      currentGpaCredits: eval.totalGpaCredits,
      totalFutureGpaCredits: remainingGpaCredits,
      targetGpa: _targetGpa,
    );
  }

  /// Dữ kiện đưa vào prompt RAG (Mục 7.4) — tính bằng code, không qua LLM
  Map<String, dynamic> buildStudentContextFacts({
    int remainingGpaCredits = 30,
    String? subjectCode,
    int? semesterNumber,
  }) {
    if (!hasTranscript) {
      return semesterNumber == null ? {} : {'target_semester': semesterNumber};
    }
    final eval = evaluation;
    final target = requiredGpaFor(remainingGpaCredits);
    final facts = <String, dynamic>{
      'current_gpa': eval.currentGpa,
      'current_semester': _entries.isEmpty
          ? null
          : _entries.map((e) => e.semester).reduce((a, b) => a > b ? a : b),
      'raw_rank': eval.rawRank,
      'actual_rank': eval.actualRank,
      'retake_count': eval.retakeCount,
      'improvement_count': eval.improvementCount,
      'has_rank_penalty': eval.hasRankPenalty,
      'penalty_warning': eval.penaltyWarning,
      'target_gpa': _targetGpa,
      'is_target_feasible': target['isFeasible'],
      'required_avg_mark': target['requiredAverage'],
      'rank_penalty_applied': eval.hasRankPenalty,
      'failed_courses': _entries
          .where((e) => !e.isPassed)
          .map((e) => e.courseCode)
          .toSet()
          .toList(),
      'completed_courses': _entries
          .where((e) => e.isPassed)
          .map((e) => e.courseCode)
          .toSet()
          .toList(),
    };
    if (subjectCode != null) {
      final history = _entries
          .where((e) =>
              GradeCalculator.normalizeCode(e.courseCode) ==
              GradeCalculator.normalizeCode(subjectCode))
          .map((e) => {
                'semester': e.semester,
                'score': e.score,
                'isPassed': e.isPassed,
              })
          .toList();
      facts['target_subject'] = GradeCalculator.normalizeCode(subjectCode);
      facts['subject_history'] = history;
    }
    if (semesterNumber != null) {
      facts['target_semester'] = semesterNumber;
    }
    return facts;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _entries = list
            .map((e) => TranscriptEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final rawStatus = prefs.getString(_customStatusKey);
      if (rawStatus != null && rawStatus.isNotEmpty) {
        final decoded = jsonDecode(rawStatus);
        if (decoded is Map) {
          _customStatusMap = <String, String>{};
          decoded.forEach((k, v) {
            if (k != null && v != null) {
              _customStatusMap[k.toString()] = v.toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[TranscriptProvider] Failed to load: $e');
      _customStatusMap = <String, String>{};
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> save(List<TranscriptEntry> confirmed) async {
    _entries = List.from(confirmed);
    _cachedResult = null; // invalidate cache
    notifyListeners();
    await _persist();
  }

  void setTargetGpa(double gpa) {
    _targetGpa = gpa.clamp(0.0, 10.0);
    notifyListeners();
  }

  Future<void> clearTranscript() async {
    _entries = [];
    _customStatusMap.clear();
    _cachedResult = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_customStatusKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  Future<void> _persistCustomStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_customStatusMap);
    await prefs.setString(_customStatusKey, json);
  }
}
