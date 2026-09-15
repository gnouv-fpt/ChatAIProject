import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';

class ServerStatusBar extends StatelessWidget {
  const ServerStatusBar({super.key});

  void _showUrlDialog(BuildContext context, ChatProvider provider) {
    final controller = TextEditingController(text: provider.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cấu hình Backend API Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập địa chỉ URL của FastAPI Backend Server (RAG / LLM):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://localhost:8000',
                labelText: 'Base URL',
                prefixIcon: Icon(Icons.dns),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.updateBaseUrl(controller.text);
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
      statusText = 'Đang kiểm tra kết nối AI Server...';
    } else if (isOnline) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade900;
      icon = Icons.check_circle;
      statusText = 'FastAPI RAG Backend: Đã kết nối';
    } else {
      bgColor = Colors.amber.shade100;
      textColor = Colors.brown.shade900;
      icon = Icons.offline_bolt_rounded;
      statusText = 'Chế độ Ngoại tuyến (Resilience Mode)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 18, color: textColor),
            tooltip: 'Kiểm tra lại kết nối',
            onPressed: () => provider.checkServerHealth(),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showUrlDialog(context, provider),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings, size: 14, color: textColor),
                  const SizedBox(width: 4),
                  Text(
                    'API Config',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
