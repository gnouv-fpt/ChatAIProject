import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/services/grade_import_service.dart';
import 'package:flm_courses/services/transcript_image_picker.dart';
import 'package:flm_courses/state/transcript_import_view_model.dart';

class Picker implements TranscriptImagePicker {
  List<ImageFile>? images;
  Object? error;
  @override
  Future<List<ImageFile>?> pick() async {
    if (error != null) throw error!;
    return images;
  }
}

class Importer extends GradeImportService {
  Importer() : super(baseUrl: 'http://unused.test');
  final completer = Completer<GradeImportResult>();
  int calls = 0;
  @override
  Future<GradeImportResult> importFromImages(List<ImageFile> images) {
    calls++;
    return completer.future;
  }
}

TranscriptEntry entry(String code, int semester, double score) =>
    TranscriptEntry(
      courseCode: code,
      semester: semester,
      score: score,
      credits: 3,
      isPassed: score >= 5,
    );
void main() {
  test('cancel picker returns idle and never calls OCR', () async {
    final api = Importer();
    final vm = TranscriptImportViewModel(picker: Picker(), service: () => api);
    expect(await vm.import(), isNull);
    expect(vm.status, ImportStatus.idle);
    expect(api.calls, 0);
    vm.dispose();
  });
  test('picker failure is recoverable without raw exception', () async {
    final vm = TranscriptImportViewModel(
      picker: Picker()..error = StateError('secret'),
      service: Importer.new,
    );
    expect(await vm.import(), isNull);
    expect(vm.status, ImportStatus.error);
    expect(vm.message, contains('nhập tay'));
    expect(vm.message, isNot(contains('secret')));
    vm.dispose();
  });
  test(
    'empty OCR result provides manual recovery and prevents duplicate requests',
    () async {
      final picker = Picker()
        ..images = [
          ImageFile(
            filename: 'test.png',
            bytes: Uint8List.fromList([1]),
            mimeType: 'image/png',
          ),
        ];
      final api = Importer();
      final vm = TranscriptImportViewModel(picker: picker, service: () => api);
      final first = vm.import();
      expect(vm.busy, isTrue);
      expect(await vm.import(), isNull);
      await Future<void>.delayed(Duration.zero);
      api.completer.complete(GradeImportResult(entries: [], warning: ''));
      expect(await first, isNull);
      expect(api.calls, 1);
      expect(vm.status, ImportStatus.empty);
      expect(vm.message, contains('nhập tay'));
      vm.dispose();
    },
  );
  test(
    'merge replaces matching semester but preserves retake and source list',
    () {
      final vm = TranscriptImportViewModel(
        picker: Picker(),
        service: Importer.new,
      );
      final saved = [entry('PRO192', 1, 4), entry('PRO192', 2, 6)];
      final merged = vm.merge(saved, [
        entry('PRO192', 2, 8),
        entry('PRM393', 6, 9),
      ]);
      expect(merged.map((e) => e.score), [4, 8, 9]);
      expect(saved.map((e) => e.score), [4, 6]);
      vm.dispose();
    },
  );
  test(
    'late OCR result after disposal does not notify or return personal rows',
    () async {
      final picker = Picker()
        ..images = [
          ImageFile(
            filename: 'test.png',
            bytes: Uint8List.fromList([1]),
            mimeType: 'image/png',
          ),
        ];
      final api = Importer();
      final vm = TranscriptImportViewModel(picker: picker, service: () => api);
      final pending = vm.import();
      await Future<void>.delayed(Duration.zero);
      vm.dispose();
      api.completer.complete(
        GradeImportResult(entries: [entry('PRO192', 1, 8)], warning: ''),
      );
      expect(await pending, isNull);
    },
  );
}
