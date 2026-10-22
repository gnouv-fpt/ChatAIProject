import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transcript_entry.dart';
import 'personal_data_repository.dart';

/// One fixed UID per instance. No account identifier is accepted from widgets.
class FirestorePersonalDataRepository implements PersonalDataRepository {
  FirestorePersonalDataRepository(this._db, this.uid);
  final FirebaseFirestore _db;
  final String uid;
  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> get _profile =>
      _user.collection('private').doc('profile');
  DocumentReference<Map<String, dynamic>> get _preferences =>
      _user.collection('private').doc('preferences');
  CollectionReference<Map<String, dynamic>> get _rows =>
      _user.collection('transcript');
  static const _server = GetOptions(source: Source.server);

  @override
  Future<Map<String, dynamic>?> loadProfile() async =>
      (await _profile.get(_server).timeout(const Duration(seconds: 20))).data();

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) =>
      _profile.set(profile).timeout(const Duration(seconds: 20));

  @override
  Future<SavedTranscript> loadTranscript() async {
    final values = await Future.wait<Object>([
      _rows.get(_server),
      _preferences.get(_server),
    ]).timeout(const Duration(seconds: 20));
    final rows = values[0] as QuerySnapshot<Map<String, dynamic>>;
    final preferences = values[1] as DocumentSnapshot<Map<String, dynamic>>;
    return SavedTranscript(
      entries: rows.docs
          .map((doc) => TranscriptEntry.fromJson(doc.data()))
          .toList(),
      targetGpa: (preferences.data()?['targetGpa'] as num?)?.toDouble() ?? 8.0,
    );
  }

  @override
  Future<void> saveTranscript(List<TranscriptEntry> entries) async {
    if (entries.length > 200) throw ArgumentError('Tối đa 200 dòng bảng điểm.');
    final incoming = <String, TranscriptEntry>{};
    for (final entry in entries) {
      if (!RegExp(r'^[A-Z0-9_]{2,24}$').hasMatch(entry.courseCode)) {
        throw ArgumentError('Mã môn không hợp lệ.');
      }
      final id = '${entry.courseCode}_${entry.semester}';
      if (incoming.containsKey(id)) {
        throw ArgumentError('Trùng môn trong cùng học kỳ.');
      }
      incoming[id] = entry;
    }
    final previous = await _rows
        .get(_server)
        .timeout(const Duration(seconds: 20));
    final batch = _db.batch();
    for (final row in previous.docs) {
      if (!incoming.containsKey(row.id)) batch.delete(row.reference);
    }
    for (final row in incoming.entries) {
      batch.set(_rows.doc(row.key), row.value.toJson());
    }
    await batch.commit().timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> saveTargetGpa(double targetGpa) => _preferences
      .set({'targetGpa': targetGpa})
      .timeout(const Duration(seconds: 20));
}
