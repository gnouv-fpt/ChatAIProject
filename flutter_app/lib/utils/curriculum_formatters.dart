/// Formatters and display helpers for curriculum, semesters, credits, and AI contexts.
/// Enforces consistent sentence-case Vietnamese and prevents exposing technical keys on UI.
library;

/// Formats total credits consistently across the application (Option A).
/// Always displays "147 tín chỉ trong khung chương trình" (or compact "147 tín chỉ" when requested),
/// completely removing the legacy 145 number from the user-facing UI without mentioning "để tốt nghiệp".
String formatCurriculumCredits(int credits, {bool fullScope = true, bool compact = false}) {
  final count = (credits <= 0 || credits == 145) ? 147 : credits;
  if (compact || !fullScope) {
    return '$count tín chỉ';
  }
  return '$count tín chỉ trong khung chương trình';
}

/// Formats total semesters consistently, making zero-semester explicit.
String formatCurriculumSemesters(int count, {int startSemester = 0, bool compact = false}) {
  if (count <= 0) return '0 học kỳ';
  if (compact) return '$count học kỳ';
  final endSemester = startSemester + count - 1;
  return '$count học kỳ (HK$startSemester–HK$endSemester)';
}

/// Converts a string to standard Vietnamese sentence case (capitalizes only the first letter).
/// Replaces undesirable Title Case (e.g. "Lộ Trình Học Tập" -> "Lộ trình học tập").
String capitalizeFirst(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}

/// Maps technical context scope identifiers into human-friendly Vietnamese labels.
///
/// Prevents exposing raw IDs like "BIT_SE_K19B:roadmap", "BIT_SE_K19B:transcript", or raw UIDs.
String formatContextScopeLabel({
  required String scope,
  required String scopeId,
  String? title,
  int? semesterNumber,
}) {
  if (scope == 'subject') {
    final cleanCode = scopeId.contains(':') ? scopeId.split(':').last : scopeId;
    return 'Môn: $cleanCode';
  }

  if (semesterNumber != null) {
    return 'Phạm vi: Học kỳ $semesterNumber';
  }

  final lowerTitle = (title ?? '').toLowerCase();
  final lowerId = scopeId.toLowerCase();

  if (lowerTitle.contains('lộ trình') || lowerId.contains('roadmap')) {
    return 'Phạm vi: Lộ trình học tập';
  }

  if (lowerTitle.contains('bảng điểm') || lowerId.contains('transcript')) {
    return 'Phạm vi: Bảng điểm cá nhân';
  }

  if (lowerTitle.contains('cài đặt') ||
      lowerTitle.contains('mục tiêu') ||
      lowerId.contains('settings')) {
    return 'Phạm vi: Mục tiêu học tập';
  }

  if (lowerTitle.contains('học kỳ') || lowerId.contains('semester')) {
    final match = RegExp(r'\d+').firstMatch(lowerTitle) ?? RegExp(r'\d+').firstMatch(lowerId);
    if (match != null) {
      return 'Phạm vi: Học kỳ ${match.group(0)}';
    }
  }

  return 'Phạm vi: Khung chương trình';
}

/// Formats a concise program degree subtitle (e.g. "Cử nhân CNTT · Kỹ thuật phần mềm")
/// avoiding duplicated prefixing like "Cử nhân CNTT · Chương trình cử nhân...".
String formatProgramSubtitle({String? nameVi, String? name}) {
  final raw = nameVi ?? name ?? '';
  if (raw.isEmpty) return 'Cử nhân CNTT · Kỹ thuật phần mềm';
  if (raw.contains('chuyên ngành ')) {
    final spec = raw.split('chuyên ngành ').last.trim();
    return 'Cử nhân CNTT · $spec';
  }
  if (!raw.contains('Chương trình') && !raw.contains('cử nhân')) {
    return 'Cử nhân CNTT · $raw';
  }
  return 'Cử nhân CNTT · Kỹ thuật phần mềm';
}

/// Formats a concise specialization or major name (e.g. "Kỹ thuật phần mềm").
String formatMajorName({String? nameVi, String? name}) {
  final raw = nameVi ?? name ?? '';
  if (raw.isEmpty) return 'Kỹ thuật phần mềm';
  if (raw.contains('chuyên ngành ')) {
    return raw.split('chuyên ngành ').last.trim();
  }
  return raw;
}
