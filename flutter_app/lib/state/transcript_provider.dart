import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transcript_entry.dart';
import '../services/grade_calculator.dart';

/// Provider toàn cục lưu transcript & GPA của sinh viên (local, không lên server).
/// Tuân thủ Mục 8.2: bảng điểm lưu local, không lưu ảnh, không đưa vào RAG chung.
class TranscriptProvider extends ChangeNotifier {
  static const _storageKey = 'flm_transcript_v1';

  List<TranscriptEntry> _entries = [];
  double _targetGpa = 8.0;
  bool _isLoaded = false;

  List<TranscriptEntry> get entries => List.unmodifiable(_entries);
  double get targetGpa => _targetGpa;
  bool get hasTranscript => _entries.isNotEmpty;
  bool get isLoaded => _isLoaded;

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
    } catch (e) {
      debugPrint('[TranscriptProvider] Failed to load: $e');
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
    _cachedResult = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }
}
