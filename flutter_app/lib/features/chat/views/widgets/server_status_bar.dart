import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';

class ServerStatusBar extends StatelessWidget {
  const ServerStatusBar({super.key});

  void _showUrlDialog(BuildContext context, ChatProvider provider) {
    var serverUrl = provider.baseUrl;
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết nối trợ lý AI'),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chỉ thay đổi địa chỉ này khi được người quản trị hướng dẫn.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: serverUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (value) => serverUrl = value,
                validator: (value) {
                  final uri = Uri.tryParse((value ?? '').trim());
                  return uri == null ||
                          uri.host.isEmpty ||
                          (uri.scheme != 'http' && uri.scheme != 'https')
                      ? 'Nhập địa chỉ bắt đầu bằng http:// hoặc https://.'
                      : null;
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'http://localhost:8000',
                  labelText: 'Địa chỉ máy chủ',
                  prefixIcon: Icon(Icons.dns),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              provider.updateBaseUrl(serverUrl.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Lưu & Kết nối'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final isOnline = provider.isServerOnline;

    Color bgColor;
    Color textColor;
    IconData icon;
    String statusText;

    if (isOnline == null) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade800;
      icon = Icons.sync;
      statusText = 'Đang kiểm tra kết nối…';
    } else if (isOnline) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade900;
      icon = Icons.check_circle;
      statusText = 'Trợ lý AI đã kết nối';
    } else {
      bgColor = Colors.amber.shade100;
      textColor = Colors.brown.shade900;
      icon = Icons.offline_bolt_rounded;
      statusText = 'Chưa kết nối trợ lý AI';
    }

    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: 18, color: textColor),
              tooltip: 'Kiểm tra lại kết nối',
              onPressed: () => provider.checkServerHealth(),
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, size: 16, color: textColor),
              tooltip: 'Cài đặt kết nối',
              onPressed: () => _showUrlDialog(context, provider),
            ),
          ],
        ),
      ),
    );
  }
}
