import '../models/transcript_entry.dart';

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
  static const List<String> excludedPrefixes = [
    'GDQP', 'ENT', 'VOV', 'TRS', 'DSA', 'LAB', 'OJS', 'OJT', 'SYB301'
  ];

  static String normalizeCode(String code) {
    return code
        .trim()
        .toUpperCase()
        .replaceAll(' ', '')
        .replaceAll('Ð', 'Đ');
  }

  static bool isExcludedFromGpa(String courseCode) {
    final norm = normalizeCode(courseCode);
    return excludedPrefixes.any((prefix) => norm == prefix || norm.startsWith(prefix));
  }

  static GradeEvaluationResult evaluateTranscript(List<TranscriptEntry> entries) {
    final sorted = List<TranscriptEntry>.from(entries)
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
          if (!attempts[i].isPassed || attempts[i].score < 5.0) {
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
        ? double.parse((totalWeightedScore / totalGpaCredits).toStringAsFixed(2))
        : 0.0;

    String rawRank = 'Kém';
    if (currentGpa >= 9.0) {
      rawRank = 'Xuất sắc';
    } else if (currentGpa >= 8.0) {
      rawRank = 'Giỏi';
    } else if (currentGpa >= 6.5) {
      rawRank = 'Khá';
    } else if (currentGpa >= 5.0) {
      rawRank = 'Trung bình';
    }

    String actualRank = rawRank;
    bool hasPenalty = false;
    if (retakeCount >= 2) {
      if (rawRank == 'Xuất sắc') {
        actualRank = 'Giỏi';
        hasPenalty = true;
      } else if (rawRank == 'Giỏi') {
        actualRank = 'Khá';
        hasPenalty = true;
      }
    }

    String penaltyWarning = '';
    if (retakeCount == 1 && (rawRank == 'Xuất sắc' || rawRank == 'Giỏi')) {
      penaltyWarning = '⚠️ Cảnh báo: Bạn đã học lại 1 môn. Nếu học lại thêm 1 môn nữa, bạn sẽ bị hạ bậc tốt nghiệp từ $rawRank xuống ${rawRank == "Xuất sắc" ? "Giỏi" : "Khá"}.';
    } else if (hasPenalty) {
      penaltyWarning = '⚠️ Bạn đã học lại $retakeCount môn (>= 2 môn), bằng tốt nghiệp bị hạ 1 bậc (từ $rawRank xuống $actualRank).';
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
      return {
        'isFeasible': false,
        'requiredAverage': 0.0,
        'message': 'Không còn tín chỉ nào ở tương lai để cải thiện.',
      };
    }

    final double requiredScore = (targetGpa * totalFinalCredits - currentWeightedScore) / totalFutureGpaCredits;
    final double rounded = double.parse(requiredScore.toStringAsFixed(2));

    if (rounded > 10.0) {
      return {
        'isFeasible': false,
        'requiredAverage': rounded,
        'message': 'Mục tiêu GPA $targetGpa không khả thi (cần đạt trung bình $rounded / 10 ở các môn còn lại).',
      };
    }

    return {
      'isFeasible': true,
      'requiredAverage': rounded > 0 ? rounded : 0.0,
      'message': 'Để đạt GPA $targetGpa, bạn cần đạt trung bình $rounded điểm cho các môn còn lại.',
    };
  }
}