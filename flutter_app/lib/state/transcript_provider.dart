import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/personal_preferences.dart';
import '../data/personal_data_repository.dart';

import '../models/transcript_entry.dart';
import '../models/load_status.dart';
import '../services/grade_calculator.dart';

/// Transcript and GPA ViewModel. Authenticated production uses a UID-bound repository.
/// Legacy local mode is retained for existing data/tests; images never enter Firestore/RAG.
class TranscriptProvider extends ChangeNotifier {
  TranscriptProvider({PersonalPreferences? storage, this.repository})
    : _storage = storage ?? PersonalPreferences();
  final PersonalDataRepository? repository;
  bool get usesCloud => repository != null;
  final PersonalPreferences _storage;
  static const _storageKey = 'flm_transcript_v1';
  static const _targetGpaKey = 'flm_target_gpa_v1';

  List<TranscriptEntry> _entries = [];
  double _targetGpa = 8.0;
  bool _isLoaded = false;
  bool _disposed = false;
  LoadStatus status = LoadStatus.loading;
  String? loadError;
  String? saveError;

  List<TranscriptEntry> get entries => List.unmodifiable(_entries);
  List<TranscriptEntry> get sortedEntries =>
      List<TranscriptEntry>.of(_entries)..sort((a, b) {
        final semester = b.semester.compareTo(a.semester);
        return semester != 0 ? semester : a.courseCode.compareTo(b.courseCode);
      });
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
          .where((e) => !e.inProgress && !e.isPassed)
          .map((e) => e.courseCode)
          .toSet()
          .toList(),
      'completed_courses': _entries
          .where((e) => !e.inProgress && e.isPassed)
          .map((e) => e.courseCode)
          .toSet()
          .toList(),
      'in_progress_courses': _entries
          .where((e) => e.inProgress)
          .map((e) => e.courseCode)
          .toSet()
          .toList(),
    };
    if (subjectCode != null) {
      final history = _entries
          .where(
            (e) =>
                GradeCalculator.normalizeCode(e.courseCode) ==
                GradeCalculator.normalizeCode(subjectCode),
          )
          .map(
            (e) => {
              'semester': e.semester,
              'score': e.score,
              'isPassed': e.isPassed,
            },
          )
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
    status = LoadStatus.loading;
    loadError = null;
    _isLoaded = false;
    _entries = [];
    _cachedResult = null;
    _notify();
    try {
      if (repository != null) {
        final saved = await repository!.loadTranscript();
        _entries = saved.entries;
        _targetGpa = saved.targetGpa.clamp(0.0, 10.0);
      } else {
        final prefs = await _storage.open();
        _targetGpa = (prefs.getDouble(_targetGpaKey) ?? 8.0).clamp(0.0, 10.0);
        final raw = prefs.getString(_storageKey);
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          _entries = list
              .map((e) => TranscriptEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      status = _entries.isEmpty ? LoadStatus.empty : LoadStatus.data;
    } catch (e) {
      status = LoadStatus.error;
      loadError = 'Không thể đọc bảng điểm đã lưu. Kiểm tra kết nối và thử lại. Dữ liệu gốc chưa bị xóa.';
      debugPrint('[TranscriptProvider] Load failed: ${e.runtimeType}');
    }
    _isLoaded = true;
    _notify();
  }

  Future<void> save(List<TranscriptEntry> confirmed) async {
    if (repository != null) {
      await repository!.saveTranscript(confirmed);
    } else {
      final prefs = await _storage.open();
      final json = jsonEncode(confirmed.map((e) => e.toJson()).toList());
      if (!await prefs.setString(_storageKey, json)) {
        throw StateError('Không thể lưu bảng điểm trên thiết bị.');
      }
    }
    _entries = List.from(confirmed);
    status = _entries.isEmpty ? LoadStatus.empty : LoadStatus.data;
    loadError = null;
    _cachedResult = null; // invalidate cache
    _notify();
  }

  void setTargetGpa(double gpa) {
    _targetGpa = gpa.clamp(0.0, 10.0);
    _notify();
    unawaited(_persistTargetGpa());
  }

  Future<void> _persistTargetGpa() async {
    try {
      if (repository != null) {
        await repository!.saveTargetGpa(_targetGpa);
      } else {
        final prefs = await _storage.open();
        await prefs.setDouble(_targetGpaKey, _targetGpa);
      }
      saveError = null;
    } catch (_) {
      saveError = 'Chưa lưu được GPA mục tiêu. Kiểm tra mạng và thử lại.';
    }
    _notify();
  }

  Future<void> clearTranscript() async {
    if (repository != null) {
      await repository!.saveTranscript([]);
    } else {
      final prefs = await _storage.open();
      if (!await prefs.remove(_storageKey)) {
        throw StateError('Không thể xóa bảng điểm trên thiết bị.');
      }
    }
    _entries = [];
    status = LoadStatus.empty;
    loadError = null;
    _cachedResult = null;
    _notify();
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
