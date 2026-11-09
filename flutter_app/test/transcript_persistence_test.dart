import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/models/load_status.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('corrupt stored transcript shows error, preserves source and supports retry', () async {
    SharedPreferences.setMockInitialValues({
      'flm_transcript_v1': '{broken json',
    });
    final provider = TranscriptProvider();
    await provider.load();
    expect(provider.status, LoadStatus.error);
    expect(provider.loadError, contains('thử lại'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('flm_transcript_v1'), '{broken json');
    await prefs.setString('flm_transcript_v1', '[]');
    await provider.load();
    expect(provider.status, LoadStatus.empty);
    expect(provider.loadError, isNull);
    await provider.save([
      TranscriptEntry(
        courseCode: 'PRM393',
        score: 8,
        credits: 3,
        semester: 6,
        isPassed: true,
      ),
    ]);
    expect(provider.status, LoadStatus.data);
    expect(provider.entries.single.score, 8);
    provider.dispose();
  });

  test('transcript survives reload and clear removes stored grades', () async {
    SharedPreferences.setMockInitialValues({});
    final first = TranscriptProvider();
    await first.load();
    await first.save([
      TranscriptEntry(
        courseCode: 'PRM393',
        score: 8.5,
        credits: 3,
        semester: 8,
        isPassed: true,
      ),
    ]);

    final reopened = TranscriptProvider();
    await reopened.load();
    expect(reopened.entries.single.courseCode, 'PRM393');
    expect(reopened.entries.single.score, 8.5);

    await reopened.clearTranscript();
    final afterClear = TranscriptProvider();
    await afterClear.load();
    expect(afterClear.entries, isEmpty);
  });
}
