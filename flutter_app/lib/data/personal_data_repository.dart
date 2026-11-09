import '../models/transcript_entry.dart';

class SavedTranscript {
  const SavedTranscript({
    required this.entries,
    required this.targetGpa,
    this.hasExplicitTargetGpa = false,
  });
  final List<TranscriptEntry> entries;
  final double targetGpa;
  final bool hasExplicitTargetGpa;
}

abstract interface class PersonalDataRepository {
  Future<Map<String, dynamic>?> loadProfile();
  Future<void> saveProfile(Map<String, dynamic> profile);
  Future<SavedTranscript> loadTranscript();
  Future<void> saveTranscript(List<TranscriptEntry> entries);
  Future<void> saveTargetGpa(double targetGpa);
}

typedef PersonalDataFactory = PersonalDataRepository Function(String uid);
