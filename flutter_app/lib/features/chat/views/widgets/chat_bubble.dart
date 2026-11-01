import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_theme.dart';
import '../../models/chat_message.dart';
import 'markdown_formatted_text.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.sender == ChatSender.user;
    final timeStr = DateFormat('HH:mm').format(message.timestamp);
    final isError = message.status == MessageStatus.error;
    final isSending = message.status == MessageStatus.sending;
    final isOffline = message.status == MessageStatus.offlineFallback;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isOffline
                  ? AppTheme.accentOrange.withValues(alpha: 0.15)
                  : colorScheme.primaryContainer,
              child: Icon(
                isOffline ? Icons.offline_bolt_rounded : Icons.smart_toy_rounded,
                color: isOffline ? AppTheme.accentOrange : colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: SelectionArea(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                decoration: BoxDecoration(
                  color: isUser
                      ? (isError ? colorScheme.errorContainer : colorScheme.primary)
                      : (isOffline
                          ? AppTheme.accentOrange.withValues(alpha: 0.08)
                          : colorScheme.surfaceContainerLow),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: Border.all(
                    color: isError
                        ? colorScheme.error
                        : isUser
                            ? Colors.transparent
                            : isOffline
                                ? AppTheme.accentOrange.withValues(alpha: 0.3)
                                : colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Offline Fallback Header Notice (AI message only)
                    if (isOffline) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.offline_bolt_rounded, size: 14, color: AppTheme.accentOrange),
                            const SizedBox(width: 6),
                            Text(
                              'Phản hồi ngoại tuyến',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Message Content Body
                    if (!isUser && isSending)
                      Semantics(
                        liveRegion: true,
                        label: 'Trợ lý đang trả lời...',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Trợ lý đang trả lời…',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      MarkdownFormattedText(text: message.text, isUser: isUser),

                    // Sources Section (Only if non-empty sources exist and not a simple greeting)
                    if (message.sources != null &&
                        message.sources!.isNotEmpty &&
                        !isSending) ...[
                      const SizedBox(height: 10),
                      Divider(height: 12, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Nguồn:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          ...message.sources!.map(
                            (src) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isUser
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                src,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isUser ? colorScheme.onPrimary : colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Error & Retry row (if sending failed)
                    if (isError) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 16, color: colorScheme.error),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              message.errorMessage ?? 'Gửi không thành công',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                          if (onRetry != null) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: onRetry,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: const Size(40, 28),
                                foregroundColor: colorScheme.error,
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text(
                                'Gửi lại',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],

                    // Footer: Timestamp + Status Icon + Copy Button
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: isUser
                                ? colorScheme.onPrimary.withValues(alpha: 0.8)
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isUser) ...[
                          const SizedBox(width: 4),
                          if (isSending)
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: colorScheme.onPrimary.withValues(alpha: 0.8),
                              ),
                            )
                          else if (isError)
                            Icon(Icons.error_outline_rounded, size: 13, color: colorScheme.error)
                          else
                            Icon(
                              Icons.done_all_rounded,
                              size: 14,
                              color: colorScheme.onPrimary.withValues(alpha: 0.85),
                            ),
                        ],
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Sao chép tin nhắn',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: message.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép nội dung tin nhắn!'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: isUser
                                ? colorScheme.onPrimary.withValues(alpha: 0.8)
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: isError ? colorScheme.errorContainer : colorScheme.primary,
              child: Icon(
                Icons.person_rounded,
                color: isError ? colorScheme.error : colorScheme.onPrimary,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
