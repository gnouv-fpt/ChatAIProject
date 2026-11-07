class CloudNotification {
  const CloudNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.destination,
    this.courseCode,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final String? destination;
  final String? courseCode;
  final bool read;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'receivedAt': receivedAt.toUtc().toIso8601String(),
    'destination': destination,
    'courseCode': courseCode,
    'read': read,
  };
}
