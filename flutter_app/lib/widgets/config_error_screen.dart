import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Clean, user-friendly error screen displayed when the release build
/// is missing mandatory compile-time configuration (such as FLM_API_BASE_URL).
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_suggest_rounded,
                      size: 38,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Lỗi cấu hình khởi động',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Bản phát hành (Release) yêu cầu cấu hình URL backend qua tham số biên dịch.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết yêu cầu:',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: colorScheme.error,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (onRetry != null)
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, AppTheme.targetSize),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standalone entry app used when configuration validation fails at startup.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cố vấn học tập FLM — Lỗi cấu hình',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: ConfigErrorScreen(message: message, onRetry: onRetry),
    );
  }
}
