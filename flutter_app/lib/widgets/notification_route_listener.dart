import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_routes.dart';
import '../services/push_service.dart';

/// Khi người dùng chạm thông báo FCM, mở màn hình tương ứng.
///
/// Đặt bên dưới Navigator (bọc màn home). Không có PushService (test, web demo)
/// thì không làm gì.
class NotificationRouteListener extends StatefulWidget {
  const NotificationRouteListener({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationRouteListener> createState() =>
      _NotificationRouteListenerState();
}

class _NotificationRouteListenerState extends State<NotificationRouteListener> {
  PushService? _push;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final push = context.read<PushService?>();
    if (identical(push, _push)) return;
    _push?.removeListener(_openPending);
    _push = push;
    push?.addListener(_openPending);
    // Thông báo mở app từ trạng thái đã đóng có thể đến trước khi màn này dựng.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  void _openPending() {
    if (!mounted) return;
    final notification = _push?.takePendingOpen();
    if (notification == null) return;
    Navigator.of(context).pushNamed(routeForNotification(notification));
  }

  @override
  void dispose() {
    _push?.removeListener(_openPending);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
