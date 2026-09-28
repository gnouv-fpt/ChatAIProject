import 'package:flutter_test/flutter_test.dart';

import '../lib/models/transcript_entry.dart';
import '../lib/services/grade_calculator.dart';

void main() {
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
      TranscriptEntry(courseCode: 'MAE101', score: 4, credits: 3, semester: 1, isPassed: false),
      TranscriptEntry(courseCode: 'MAE101', score: 7, credits: 3, semester: 2, isPassed: true),
      TranscriptEntry(courseCode: 'PRM393', score: 6, credits: 3, semester: 1, isPassed: true),
      TranscriptEntry(courseCode: 'PRM393', score: 8, credits: 3, semester: 2, isPassed: true),
    ]);

    expect(result.retakeCount, 1);
    expect(result.improvementCount, 1);
    expect(result.currentGpa, 7.5);
  });
}
