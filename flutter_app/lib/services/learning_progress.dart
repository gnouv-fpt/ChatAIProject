import '../models/course.dart';
import '../models/transcript_entry.dart';

enum CourseReadiness { completed, inProgress, ready, blocked, unverified }

class CourseProgress {
  const CourseProgress({
    required this.readiness,
    this.score,
    this.missingPrerequisites = const [],
    this.unverifiedPrerequisites = const [],
  });

  final CourseReadiness readiness;
  final double? score;
  final List<String> missingPrerequisites;
  final List<String> unverifiedPrerequisites;
}

/// Academic status is derived only from the confirmed transcript and curriculum.
class LearningProgress {
  LearningProgress(
    List<Course> courses,
    List<TranscriptEntry> transcript, {
    int? currentSemester,
  }) : _courses = {for (final course in courses) _code(course.code): course},
       _entries = transcript,
       _reportedCurrentSemester = currentSemester;

  final Map<String, Course> _courses;
  final List<TranscriptEntry> _entries;
  final int? _reportedCurrentSemester;

  static String _code(String value) =>
      value.trim().toUpperCase().replaceAll('Ð', 'Đ');

  Set<String> get completedCodes => _entries
      .where((entry) => !entry.inProgress && entry.isPassed)
      .map((entry) => _code(entry.courseCode))
      .toSet();

  Set<String> get inProgressCodes => _entries
      .where((entry) => entry.inProgress)
      .map((entry) => _code(entry.courseCode))
      .where((code) => !completedCodes.contains(code))
      .toSet();

  /// A past failed attempt is no longer a debt once the course has been passed.
  Set<String> get failedCodes => _entries
      .where((entry) => !entry.inProgress && !entry.isPassed)
      .map((entry) => _code(entry.courseCode))
      .where(
        (code) =>
            _courses.containsKey(code) &&
            !completedCodes.contains(code) &&
            !inProgressCodes.contains(code),
      )
      .toSet();

  int get totalCount => _courses.length;
  int get completedCount => _courses.keys.where(completedCodes.contains).length;
  int get ongoingCount => _courses.keys.where(inProgressCodes.contains).length;
  int get remainingCount => totalCount - completedCount;
  double get completionRatio =>
      totalCount == 0 ? 0 : completedCount / totalCount;

  List<SemesterProgress> get semesters {
    final numbers =
        _courses.values.map((course) => course.semester).toSet().toList()
          ..sort();
    return [
      for (final semester in numbers)
        SemesterProgress(
          semester: semester,
          total: _courses.values
              .where((course) => course.semester == semester)
              .length,
          completed: _courses.values
              .where(
                (course) =>
                    course.semester == semester &&
                    completedCodes.contains(_code(course.code)),
              )
              .length,
        ),
    ];
  }

  /// Null means there is no confirmed semester information yet.
  int? get currentSemester {
    if (_reportedCurrentSemester != null) return _reportedCurrentSemester;
    final ongoing = _entries.where((entry) => entry.inProgress).toList();
    final source = ongoing.isNotEmpty ? ongoing : _entries;
    if (source.isEmpty) return null;
    return source
        .map((entry) => entry.semester)
        .reduce((a, b) => a > b ? a : b);
  }

  int? get nextSemester =>
      currentSemester == null ? null : currentSemester! + 1;

  List<Course> get nextSemesterCourses {
    final semester = nextSemester;
    if (semester == null) return const [];
    return _courses.values
        .where((course) => course.semester == semester)
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  CourseProgress status(Course course) {
    final code = _code(course.code);
    if (completedCodes.contains(code)) {
      final passed = _entries.where(
        (entry) =>
            _code(entry.courseCode) == code &&
            !entry.inProgress &&
            entry.isPassed,
      );
      return CourseProgress(
        readiness: CourseReadiness.completed,
        score: passed.isEmpty ? null : passed.last.score,
      );
    }
    if (inProgressCodes.contains(code)) {
      return const CourseProgress(readiness: CourseReadiness.inProgress);
    }
    final prerequisites = course.prerequisitesNorm.isNotEmpty
        ? course.prerequisitesNorm
        : course.prerequisites;
    final unknown = <String>[];
    final missing = <String>[];
    for (final raw in prerequisites) {
      final prerequisite = _code(raw);
      if (!_courses.containsKey(prerequisite)) {
        unknown.add(prerequisite);
      } else if (!completedCodes.contains(prerequisite)) {
        missing.add(prerequisite);
      }
    }
    return CourseProgress(
      readiness: unknown.isNotEmpty
          ? CourseReadiness.unverified
          : missing.isNotEmpty
          ? CourseReadiness.blocked
          : CourseReadiness.ready,
      missingPrerequisites: missing,
      unverifiedPrerequisites: unknown,
    );
  }
}

class SemesterProgress {
  const SemesterProgress({
    required this.semester,
    required this.total,
    required this.completed,
  });
  final int semester;
  final int total;
  final int completed;
}
