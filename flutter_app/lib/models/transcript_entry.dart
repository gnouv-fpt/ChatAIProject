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
    return TranscriptEntry(
      courseCode: json['courseCode'] ?? '',
      courseName: json['courseName'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      credits: (json['credits'] as num?)?.toInt() ?? 3,
      semester: (json['semester'] as num?)?.toInt() ?? 1,
      isPassed: json['isPassed'] ?? (json['score'] != null && json['score'] >= 5.0),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}