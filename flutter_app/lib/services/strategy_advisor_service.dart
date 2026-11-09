import '../models/transcript_entry.dart';
import 'grade_calculator.dart';

enum ConsultationLevel { subject, semester, fullRoadmap }

class StrategyAdvisorService {
  static Map<String, dynamic> buildAdvisorPayload({
    required ConsultationLevel level,
    required List<TranscriptEntry> transcript,
    required double targetGpa,
    String? subjectCode,
    int? semesterNumber,
    int totalRemainingCredits = 30,
  }) {
    final eval = GradeCalculator.evaluateTranscript(transcript);
    final targetEval = GradeCalculator.calculateRequiredGpa(
      currentWeightedScore: eval.currentGpa * eval.totalGpaCredits,
      currentGpaCredits: eval.totalGpaCredits,
      totalFutureGpaCredits: totalRemainingCredits,
      targetGpa: targetGpa,
    );

    final Map<String, dynamic> facts = {
      'level': level.name,
      'currentGpa': eval.currentGpa,
      'rawRank': eval.rawRank,
      'actualRank': eval.actualRank,
      'retakeCount': eval.retakeCount,
      'hasRankPenalty': eval.hasRankPenalty,
      'penaltyWarning': eval.penaltyWarning,
      'targetGpa': targetGpa,
      'isTargetFeasible': targetEval['isFeasible'],
      'requiredAverageForTarget': targetEval['requiredAverage'],
    };

    if (level == ConsultationLevel.subject && subjectCode != null) {
      facts['targetSubject'] = GradeCalculator.normalizeCode(subjectCode);
      final history = transcript
          .where((e) => GradeCalculator.normalizeCode(e.courseCode) == GradeCalculator.normalizeCode(subjectCode))
          .map((e) => {'semester': e.semester, 'score': e.score, 'isPassed': e.isPassed})
          .toList();
      facts['subjectHistory'] = history;
    } else if (level == ConsultationLevel.semester && semesterNumber != null) {
      facts['targetSemester'] = semesterNumber;
    }

    return facts;
  }
}