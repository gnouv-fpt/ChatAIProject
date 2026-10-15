import 'package:flutter_test/flutter_test.dart';

import '../lib/models/transcript_entry.dart';
import '../lib/services/grade_calculator.dart';

void main() {
  testWidgets('loads the shared grading rules asset', (tester) async {
    await GradeCalculator.loadRules();
    expect(GradeCalculator.isExcludedFromGpa('VOV114'), isTrue);
    expect(GradeCalculator.isExcludedFromGpa('PRM393'), isFalse);
  });

  test('parses FastAPI snake_case transcript rows', () {
    final entry = TranscriptEntry.fromJson({
      'course_code': ' prm393 ',
      'score': 8.5,
      'credits': 3,
      'semester': 6,
      'status': 'passed',
      'confidence': 0.72,
    });

    expect(entry.courseCode, 'PRM393');
    expect(entry.score, 8.5);
    expect(entry.credits, 3);
    expect(entry.semester, 6);
    expect(entry.isPassed, isTrue);
    expect(entry.confidence, 0.72);
  });

  test('counts failed retakes but not grade improvements', () {
    final result = GradeCalculator.evaluateTranscript([
      TranscriptEntry(
        courseCode: 'MAE101',
        score: 4,
        credits: 3,
        semester: 1,
        isPassed: false,
      ),
      TranscriptEntry(
        courseCode: 'MAE101',
        score: 7,
        credits: 3,
        semester: 2,
        isPassed: true,
      ),
      TranscriptEntry(
        courseCode: 'PRM393',
        score: 6,
        credits: 3,
        semester: 1,
        isPassed: true,
      ),
      TranscriptEntry(
        courseCode: 'PRM393',
        score: 8,
        credits: 3,
        semester: 2,
        isPassed: true,
      ),
    ]);

    expect(result.retakeCount, 1);
    expect(result.improvementCount, 1);
    expect(result.currentGpa, 7.5);
  });

  test('an in-progress OCR row does not lower GPA or count as a retake', () {
    final pending = TranscriptEntry.fromJson({
      'course_code': 'PRM393',
      'status': 'in_progress',
      'semester': 8,
      'credits': 3,
    });
    final completed = TranscriptEntry(
      courseCode: 'PRM393',
      score: 8,
      credits: 3,
      semester: 7,
      isPassed: true,
    );
    final result = GradeCalculator.evaluateTranscript([completed, pending]);
    expect(pending.inProgress, isTrue);
    expect(result.currentGpa, 8);
    expect(result.retakeCount, 0);
    expect(result.totalGpaCredits, 3);
  });

  test('zero remaining credits does not invent future courses', () {
    final met = GradeCalculator.calculateRequiredGpa(
      currentWeightedScore: 24,
      currentGpaCredits: 3,
      totalFutureGpaCredits: 0,
      targetGpa: 8,
    );
    final unmet = GradeCalculator.calculateRequiredGpa(
      currentWeightedScore: 21,
      currentGpaCredits: 3,
      totalFutureGpaCredits: 0,
      targetGpa: 8,
    );
    expect(met['isFeasible'], isTrue);
    expect(unmet['isFeasible'], isFalse);
  });
}
