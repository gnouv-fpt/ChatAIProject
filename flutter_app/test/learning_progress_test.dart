import 'package:flutter_test/flutter_test.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/services/learning_progress.dart';

Course course(String code, int semester, List<String> prerequisites) => Course(
  code: code,
  codeOriginal: code,
  name: code,
  credits: 3,
  semester: semester,
  learningOutcomes: const [],
  prerequisites: prerequisites,
  prerequisitesNorm: prerequisites,
  unlocks: const [],
);

TranscriptEntry entry(
  String code,
  int semester, {
  bool passed = true,
  bool inProgress = false,
  double score = 8,
}) => TranscriptEntry(
  courseCode: code,
  semester: semester,
  score: score,
  credits: 3,
  isPassed: passed,
  inProgress: inProgress,
);

void main() {
  test('journey counts distinct catalog courses and clears resolved debts', () {
    final progress = LearningProgress(
      [
        course('BAS101', 1, []),
        course('BAS102', 1, []),
        course('ADV201', 2, []),
        course('ADV202', 2, []),
      ],
      [
        entry('BAS101', 1, passed: false),
        entry('BAS101', 2),
        entry('BAS101', 3),
        entry('BAS102', 1, passed: false),
        entry('ADV201', 2, passed: false, inProgress: true),
        entry('OTHER101', 1),
      ],
    );
    expect(progress.totalCount, 4);
    expect(progress.completedCount, 1);
    expect(progress.remainingCount, 3);
    expect(progress.ongoingCount, 1);
    expect(progress.failedCodes, {'BAS102'});
    expect(progress.completionRatio, 0.25);
    expect(
      progress.semesters.map((s) => '${s.semester}:${s.completed}/${s.total}'),
      ['1:1/2', '2:0/2'],
    );
    expect(LearningProgress([], []).completionRatio, 0);
  });
  test('next semester does not recommend blocked or unknown prerequisites', () {
    final courses = [
      course('BAS101', 1, []),
      course('BAS102', 2, []),
      course('ADV201', 3, ['BAS101']),
      course('ADV202', 3, ['BAS102']),
      course('ADV203', 3, ['MISSING101']),
    ];
    final progress = LearningProgress(courses, [
      entry('BAS101', 1, score: 7.5),
      entry('BAS102', 2, passed: false, inProgress: true),
    ]);
    expect(progress.currentSemester, 2);
    expect(progress.nextSemesterCourses.map((c) => c.code), [
      'ADV201',
      'ADV202',
      'ADV203',
    ]);
    expect(progress.status(courses[0]).score, 7.5);
    expect(progress.status(courses[1]).readiness, CourseReadiness.inProgress);
    expect(progress.status(courses[2]).readiness, CourseReadiness.ready);
    expect(progress.status(courses[3]).missingPrerequisites, ['BAS102']);
    expect(progress.status(courses[4]).readiness, CourseReadiness.unverified);
  });

  test('confirmed current semester overrides transcript inference', () {
    final courses = [
      course('BAS101', 1, []),
      course('ADV201', 4, ['BAS101']),
    ];
    final progress = LearningProgress(courses, [
      entry('BAS101', 1),
    ], currentSemester: 3);
    expect(progress.currentSemester, 3);
    expect(progress.nextSemesterCourses.map((c) => c.code), ['ADV201']);
    expect(progress.status(courses[1]).readiness, CourseReadiness.ready);
  });
}
