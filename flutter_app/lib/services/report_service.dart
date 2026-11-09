import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transcript_entry.dart';

class ReportUploadResult {
  const ReportUploadResult({required this.path, required this.url});
  final String path;
  final String url;
}

class ReportService {
  ReportService(this._storage, this._db);

  final FirebaseStorage _storage;
  final FirebaseFirestore _db;

  Future<Uint8List> createTranscriptPdf(
    List<TranscriptEntry> entries, {
    required double targetGpa,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'FLM Student Progress Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          ),
          pw.Text('Target GPA: ${targetGpa.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Course',
              'Name',
              'Semester',
              'Credits',
              'Score',
              'Status',
            ],
            data: entries
                .map(
                  (entry) => [
                    entry.courseCode,
                    entry.courseName,
                    entry.semester,
                    entry.credits,
                    entry.score.toStringAsFixed(1),
                    entry.inProgress
                        ? 'In progress'
                        : entry.isPassed
                        ? 'Passed'
                        : 'Not passed',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<ReportUploadResult> upload({
    required String uid,
    required Uint8List bytes,
    required void Function(double progress) onProgress,
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > 10 * 1024 * 1024) {
      throw ArgumentError('Báo cáo phải có dung lượng từ 1 byte đến 10 MB.');
    }
    final id = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final path = 'reports/$uid/$id.pdf';
    final ref = _storage.ref(path);
    final task = ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {'ownerUid': uid},
      ),
    );
    final progressSubscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    try {
      await task;
    } finally {
      await progressSubscription.cancel();
    }
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).collection('reports').doc(id).set({
      'path': path,
      'sizeBytes': bytes.lengthInBytes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ReportUploadResult(path: path, url: url);
  }
}
