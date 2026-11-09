import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import '../models/transcript_entry.dart';

class _GradeRules {
  _GradeRules({
    required this.excluded,
    required this.passingScore,
    required this.penaltyThreshold,
    required this.penaltyLevels,
    required this.penaltyRanks,
    required this.graduationThresholds,
    required this.labels,
    required this.rankOrder,
    required this.maxScore,
  });

  final List<String> excluded;
  final double passingScore;
  final int penaltyThreshold;
  final int penaltyLevels;
  final Set<String> penaltyRanks;
  final Map<String, double> graduationThresholds;
  final Map<String, String> labels;
  final List<String> rankOrder;
  final double maxScore;

  factory _GradeRules.fromYaml(String source) {
    final root = loadYaml(source) as YamlMap;
    final retake = root['retake'] as YamlMap;
    final thresholds = root['graduation_grades'] as YamlMap;
    final gradeLabels = root['grade_labels_vi'] as YamlMap;
    return _GradeRules(
      excluded: (root['excluded_from_gpa'] as YamlList)
          .map((value) => value.toString())
          .toList(),
      passingScore: (root['retake_definition']['passing_score'] as num)
          .toDouble(),
      penaltyThreshold: (retake['penalty_threshold'] as num).toInt(),
      penaltyLevels: (retake['penalty_levels'] as num).toInt(),
      penaltyRanks: (retake['applies_to'] as YamlList)
          .map((value) => value.toString())
          .toSet(),
      graduationThresholds: {
        for (final entry in thresholds.entries)
          entry.key.toString(): (entry.value as num).toDouble(),
      },
      labels: {
        for (final entry in gradeLabels.entries)
          entry.key.toString(): entry.value.toString(),
      },
      rankOrder: (root['grade_order'] as YamlList)
          .map((value) => value.toString())
          .toList(),
      maxScore: (root['target_gpa']['max_score'] as num).toDouble(),
    );
  }
}

class GradeEvaluationResult {
  final double currentGpa;
  final int totalAccumulatedCredits;
  final int totalGpaCredits;
  final int retakeCount;
  final int improvementCount;
  final String rawRank;
  final String actualRank;
  final bool hasRankPenalty;
  final String penaltyWarning;

  GradeEvaluationResult({
    required this.currentGpa,
    required this.totalAccumulatedCredits,
    required this.totalGpaCredits,
    required this.retakeCount,
    required this.improvementCount,
    required this.rawRank,
    required this.actualRank,
    required this.hasRankPenalty,
    required this.penaltyWarning,
  });
}

class GradeCalculator {
  static _GradeRules? _rules;

  static Future<void> loadRules() async {
    _rules = _GradeRules.fromYaml(
      await rootBundle.loadString('assets/grading_rules.yaml'),
    );
  }

  static List<String> get excludedPrefixes =>
      _rules?.excluded ??
      const ['GDQP', 'ENT', 'VOV', 'TRS', 'DSA', 'LAB', 'OJS', 'OJT', 'SYB301'];

  static String normalizeCode(String code) {
    return code.trim().toUpperCase().replaceAll(' ', '').replaceAll('Ð', 'Đ');
  }

  static bool isExcludedFromGpa(String courseCode) {
    final norm = normalizeCode(courseCode);
    return excludedPrefixes.any(
      (prefix) => norm == prefix || norm.startsWith(prefix),
    );
  }

  static GradeEvaluationResult evaluateTranscript(
    List<TranscriptEntry> entries,
  ) {
    final sorted = entries.where((entry) => !entry.inProgress).toList()
      ..sort((a, b) => a.semester.compareTo(b.semester));

    final Map<String, List<TranscriptEntry>> historyMap = {};
    for (var entry in sorted) {
      final code = normalizeCode(entry.courseCode);
      historyMap.putIfAbsent(code, () => []).add(entry);
    }

    int retakeCount = 0;
    int improvementCount = 0;
    final Map<String, TranscriptEntry> lastAttemptMap = {};

    for (var entry in historyMap.entries) {
      final attempts = entry.value;
      lastAttemptMap[entry.key] = attempts.last;

      if (attempts.length > 1) {
        bool hadFailedPrior = false;
        for (int i = 0; i < attempts.length - 1; i++) {
          if (!attempts[i].isPassed ||
              attempts[i].score < (_rules?.passingScore ?? 5.0)) {
            hadFailedPrior = true;
            break;
          }
        }
        if (hadFailedPrior) {
          retakeCount++;
        } else {
          improvementCount++;
        }
      }
    }

    double totalWeightedScore = 0.0;
    int totalGpaCredits = 0;
    int totalAccumulatedCredits = 0;

    for (var entry in lastAttemptMap.values) {
      if (entry.isPassed) totalAccumulatedCredits += entry.credits;
      if (!isExcludedFromGpa(entry.courseCode)) {
        totalWeightedScore += entry.score * entry.credits;
        totalGpaCredits += entry.credits;
      }
    }

    final double currentGpa = totalGpaCredits > 0
        ? double.parse(
            (totalWeightedScore / totalGpaCredits).toStringAsFixed(2),
          )
        : 0.0;

    final thresholds =
        _rules?.graduationThresholds ??
        const {'Excellent': 9.0, 'Good': 8.0, 'Fair': 6.5, 'Pass': 5.0};
    final labels =
        _rules?.labels ??
        const {
          'Excellent': 'Xuất sắc',
          'Good': 'Giỏi',
          'Fair': 'Khá',
          'Pass': 'Trung bình',
          'Fail': 'Kém',
        };
    final rankOrder =
        _rules?.rankOrder ?? const ['Excellent', 'Good', 'Fair', 'Pass'];
    String rankKey = 'Fail';
    for (final key in rankOrder) {
      if (currentGpa >= (thresholds[key] ?? double.infinity)) {
        rankKey = key;
        break;
      }
    }
    final rawRank = labels[rankKey] ?? rankKey;

    String actualRank = rawRank;
    bool hasPenalty = false;
    final penaltyThreshold = _rules?.penaltyThreshold ?? 2;
    final penaltyRanks = _rules?.penaltyRanks ?? const {'Excellent', 'Good'};
    final penaltyLevels = _rules?.penaltyLevels ?? 1;
    if (retakeCount >= penaltyThreshold && penaltyRanks.contains(rankKey)) {
      final index = rankOrder.indexOf(rankKey);
      final actualKey =
          rankOrder[(index + penaltyLevels).clamp(0, rankOrder.length - 1)];
      actualRank = labels[actualKey] ?? actualKey;
      hasPenalty = true;
    }

    String penaltyWarning = '';
    if (retakeCount == penaltyThreshold - 1 && penaltyRanks.contains(rankKey)) {
      penaltyWarning =
          '⚠️ Cảnh báo: Bạn đã học lại $retakeCount môn. Nếu học lại thêm 1 môn nữa, bạn sẽ bị hạ bậc tốt nghiệp từ $rawRank.';
    } else if (hasPenalty) {
      penaltyWarning =
          '⚠️ Bạn đã học lại $retakeCount môn (>= $penaltyThreshold môn), bằng tốt nghiệp bị hạ $penaltyLevels bậc (từ $rawRank xuống $actualRank).';
    }

    return GradeEvaluationResult(
      currentGpa: currentGpa,
      totalAccumulatedCredits: totalAccumulatedCredits,
      totalGpaCredits: totalGpaCredits,
      retakeCount: retakeCount,
      improvementCount: improvementCount,
      rawRank: rawRank,
      actualRank: actualRank,
      hasRankPenalty: hasPenalty,
      penaltyWarning: penaltyWarning,
    );
  }

  static Map<String, dynamic> calculateRequiredGpa({
    required double currentWeightedScore,
    required int currentGpaCredits,
    required int totalFutureGpaCredits,
    required double targetGpa,
  }) {
    final int totalFinalCredits = currentGpaCredits + totalFutureGpaCredits;
    if (totalFutureGpaCredits <= 0) {
      final currentGpa = currentGpaCredits > 0
          ? currentWeightedScore / currentGpaCredits
          : 0.0;
      return {
        'isFeasible': currentGpaCredits > 0 && currentGpa >= targetGpa,
        'requiredAverage': 0.0,
        'message': currentGpaCredits > 0 && currentGpa >= targetGpa
            ? 'Bạn đã đạt mục tiêu GPA hiện tại.'
            : 'Không còn tín chỉ nào ở tương lai để đạt mục tiêu GPA.',
      };
    }

    final double requiredScore =
        (targetGpa * totalFinalCredits - currentWeightedScore) /
        totalFutureGpaCredits;
    final double rounded = double.parse(requiredScore.toStringAsFixed(2));

    if (rounded > (_rules?.maxScore ?? 10.0)) {
      return {
        'isFeasible': false,
        'requiredAverage': rounded,
        'message':
            'Mục tiêu GPA $targetGpa không khả thi (cần đạt trung bình $rounded / 10 ở các môn còn lại).',
      };
    }

    return {
      'isFeasible': true,
      'requiredAverage': rounded > 0 ? rounded : 0.0,
      'message':
          'Để đạt GPA $targetGpa, bạn cần đạt trung bình $rounded điểm cho các môn còn lại.',
    };
  }
}
