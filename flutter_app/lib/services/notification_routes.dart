import '../models/cloud_notification.dart';

/// Route mở trung tâm thông báo (màn Firebase Lab 3).
const notificationCenterRoute = '/cloud-hub';

final _courseCodePattern = RegExp(r'^[A-Za-z]{2,5}\d{3}[A-Za-z]?$');

/// Ánh xạ dữ liệu của thông báo FCM sang route trong app.
///
/// Dữ liệu gửi từ Console (custom data):
/// - `destination=course` + `course_code=CSD201` → chi tiết môn học.
/// - `destination=cloud_hub` hoặc `notifications` → trung tâm thông báo.
/// - Giá trị khác hoặc thiếu → có mã môn hợp lệ thì mở môn đó,
///   không thì mở trung tâm thông báo để người dùng vẫn thấy nội dung.
String routeForNotification(CloudNotification notification) {
  final code = notification.courseCode?.trim();
  final hasValidCode = code != null && _courseCodePattern.hasMatch(code);
  switch (notification.destination?.trim()) {
    case 'course':
      return hasValidCode ? '/courses/$code' : notificationCenterRoute;
    case 'cloud_hub':
    case 'notifications':
      return notificationCenterRoute;
    default:
      return hasValidCode ? '/courses/$code' : notificationCenterRoute;
  }
}
