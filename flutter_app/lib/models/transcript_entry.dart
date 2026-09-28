class TranscriptEntry {
  String courseCode;
  String courseName;
  double score;
  int credits;
  int semester;
  bool isPassed;
  double confidence;

  TranscriptEntry({
    required this.courseCode,
    this.courseName = '',
    required this.score,
    required this.credits,
    required this.semester,
    required this.isPassed,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'courseCode': courseCode,
    'courseName': courseName,
    'score': score,
    'credits': credits,
    'semester': semester,
    'isPassed': isPassed,
    'confidence': confidence,
  };

  factory TranscriptEntry.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] as num?)?.toDouble() ?? 0.0;
    final status = json['status']?.toString();
    return TranscriptEntry(
      // FastAPI responses use snake_case; local SharedPreferences uses camelCase.
      courseCode: _normalizeCode((json['courseCode'] ?? json['course_code'] ?? '').toString()),
      courseName: (json['courseName'] ?? json['course_name'] ?? '').toString(),
      score: score,
      credits: ((json['credits'] ?? 3) as num).toInt(),
      semester: ((json['semester'] ?? 1) as num).toInt(),
      isPassed: (json['isPassed'] ?? (status == 'passed' || score >= 5.0)) as bool,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static String _normalizeCode(String code) {
    return code
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('Ð', 'Đ')
        .toUpperCase();
  }
}
