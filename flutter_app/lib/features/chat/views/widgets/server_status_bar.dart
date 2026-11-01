import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';

class ServerStatusBar extends StatelessWidget {
  const ServerStatusBar({super.key});

  void _showUrlDialog(BuildContext context, ChatProvider provider) {
    var serverUrl = provider.baseUrl;
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết nối trợ lý AI (Debug)'),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chỉ thay đổi địa chỉ này khi đang phát triển hoặc kiểm thử cục bộ.',
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

    // When server is online, keep screen completely clean by hiding the bar
    if (isOnline == true) {
      return const SizedBox.shrink();
    }

    final isChecking = isOnline == null;
    final dotColor = isChecking ? AppTheme.accentOrange : AppTheme.danger;
    final labelText = isChecking ? 'Đang kiểm tra kết nối trợ lý…' : 'Trợ lý ngoại tuyến';

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isChecking
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
              : AppTheme.danger.withValues(alpha: 0.08),
          border: Border(
            bottom: BorderSide(
              color: isChecking
                  ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)
                  : AppTheme.danger.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                labelText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isChecking
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : AppTheme.danger,
                ),
              ),
            ),
            TextButton(
              onPressed: provider.checkServerHealth,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                minimumSize: const Size(40, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Thử lại', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
            if (!kReleaseMode) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 16),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Cài đặt kết nối máy chủ (Debug)',
                onPressed: () => _showUrlDialog(context, provider),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
