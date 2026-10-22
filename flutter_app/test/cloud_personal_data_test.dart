import 'package:flutter_test/flutter_test.dart';
import 'package:flm_courses/data/personal_data_repository.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/models/load_status.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';

class Repository implements PersonalDataRepository {
  Map<String, dynamic>? profile;
  List<TranscriptEntry> entries = [];
  double target = 8;
  bool failing = false;
  void check() {
    if (failing) throw StateError('permission-denied');
  }

  @override
  Future<Map<String, dynamic>?> loadProfile() async {
    check();
    return profile;
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> data) async {
    check();
    profile = Map.of(data);
  }

  @override
  Future<SavedTranscript> loadTranscript() async {
    check();
    return SavedTranscript(entries: List.of(entries), targetGpa: target);
  }

  @override
  Future<void> saveTranscript(List<TranscriptEntry> data) async {
    check();
    entries = List.of(data);
  }

  @override
  Future<void> saveTargetGpa(double value) async {
    check();
    target = value;
  }
}

void main() {
  test('profile persists through repository and failed save preserves previous profile', () async {
    final repo = Repository();
    final first = LearningProfileProvider(repository: repo);
    await first.load();
    await first.update(courseGoal: 'high_score', currentSemester: 4);
    final reopened = LearningProfileProvider(repository: repo);
    await reopened.load();
    expect(reopened.courseGoal, 'high_score');
    expect(reopened.currentSemester, 4);
    repo.failing = true;
    await expectLater(reopened.update(courseGoal: 'pass'), throwsStateError);
    expect(reopened.courseGoal, 'high_score');
    expect(reopened.error, contains('thử lại'));
    first.dispose();
    reopened.dispose();
  });
  test(
    'cloud load error is distinguishable from empty profile and supports retry',
    () async {
      final repo = Repository()..failing = true;
      final vm = LearningProfileProvider(repository: repo);
      await vm.load();
      expect(vm.status, LoadStatus.error);
      expect(vm.isLoaded, isFalse);
      repo.failing = false;
      await vm.load(retry: true);
      expect(vm.status, LoadStatus.empty);
      expect(vm.error, isNull);
      vm.dispose();
    },
  );
  test('transcript reopens from repository and failed save keeps last confirmed data', () async {
    final repo = Repository();
    final first = TranscriptProvider(repository: repo);
    await first.load();
    await first.save([
      TranscriptEntry(
        courseCode: 'PRO192',
        score: 8,
        credits: 3,
        semester: 1,
        isPassed: true,
      ),
    ]);
    final reopened = TranscriptProvider(repository: repo);
    await reopened.load();
    expect(reopened.entries.single.courseCode, 'PRO192');
    expect(reopened.status, LoadStatus.data);
    repo.failing = true;
    await expectLater(reopened.save([]), throwsStateError);
    expect(reopened.entries, hasLength(1));
    repo.failing = false;
    await reopened.clearTranscript();
    expect(repo.entries, isEmpty);
    expect(reopened.status, LoadStatus.empty);
    first.dispose();
    reopened.dispose();
  });
  test(
    'cloud read failure shows retry instead of an empty successful transcript',
    () async {
      final repo = Repository()..failing = true;
      final vm = TranscriptProvider(repository: repo);
      await vm.load();
      expect(vm.status, LoadStatus.error);
      expect(vm.loadError, contains('thử lại'));
      repo.failing = false;
      await vm.load();
      expect(vm.status, LoadStatus.empty);
      expect(vm.loadError, isNull);
      vm.dispose();
    },
  );
}
