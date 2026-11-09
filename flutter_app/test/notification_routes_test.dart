import 'package:flm_courses/models/cloud_notification.dart';
import 'package:flm_courses/services/notification_routes.dart';
import 'package:flutter_test/flutter_test.dart';

CloudNotification _notification({String? destination, String? courseCode}) =>
    CloudNotification(
      id: 'n1',
      title: 'Thông báo',
      body: '',
      receivedAt: DateTime.utc(2026, 11, 9),
      destination: destination,
      courseCode: courseCode,
    );

void main() {
  group('routeForNotification', () {
    test('course destination with valid code opens course detail', () {
      expect(
        routeForNotification(
          _notification(destination: 'course', courseCode: 'CSD201'),
        ),
        '/courses/CSD201',
      );
      expect(
        routeForNotification(
          _notification(destination: 'course', courseCode: ' ENW493c '),
        ),
        '/courses/ENW493c',
      );
    });

    test('course destination with missing or invalid code falls back', () {
      expect(
        routeForNotification(_notification(destination: 'course')),
        notificationCenterRoute,
      );
      expect(
        routeForNotification(
          _notification(destination: 'course', courseCode: '../admin'),
        ),
        notificationCenterRoute,
      );
    });

    test('notification center destinations open cloud hub', () {
      for (final destination in ['cloud_hub', 'notifications']) {
        expect(
          routeForNotification(
            _notification(destination: destination, courseCode: 'CSD201'),
          ),
          notificationCenterRoute,
        );
      }
    });

    test('unknown destination uses course code when valid', () {
      expect(
        routeForNotification(_notification(courseCode: 'PRM393')),
        '/courses/PRM393',
      );
      expect(
        routeForNotification(_notification(destination: 'unknown')),
        notificationCenterRoute,
      );
    });
  });
}
