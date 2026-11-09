import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firebase_app_telemetry.dart';
import '../services/push_service.dart';
import '../services/report_service.dart';
import '../state/auth_view_model.dart';
import '../state/feature_config.dart';
import '../state/transcript_provider.dart';

class CloudHubScreen extends StatefulWidget {
  const CloudHubScreen({super.key});

  @override
  State<CloudHubScreen> createState() => _CloudHubScreenState();
}

class _CloudHubScreenState extends State<CloudHubScreen> {
  Uint8List? _report;
  double _uploadProgress = 0;
  String? _reportUrl;
  String? _message;
  bool _busy = false;

  Future<void> _createReport() async {
    final transcript = context.read<TranscriptProvider>();
    final reportService = context.read<ReportService>();
    final telemetry = context.read<FirebaseAppTelemetry>();
    if (transcript.entries.isEmpty) {
      setState(() => _message = 'Hãy nhập bảng điểm trước khi tạo báo cáo.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await reportService.createTranscriptPdf(
        transcript.entries,
        targetGpa: transcript.targetGpa,
      );
      await telemetry.event('export_report', {
        'row_count': transcript.entries.length,
        'file_size_kb': (bytes.lengthInBytes / 1024).round(),
      });
      setState(() {
        _report = bytes;
        _message = 'Đã tạo báo cáo PDF từ ${transcript.entries.length} môn.';
      });
    } catch (error, stack) {
      await telemetry.nonFatal(error, stack, flow: 'report_create');
      setState(() => _message = 'Không tạo được báo cáo. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final bytes = _report;
    final uid = context.read<AuthViewModel>().account?.uid;
    if (bytes == null || uid == null) return;
    final reportService = context.read<ReportService>();
    final telemetry = context.read<FirebaseAppTelemetry>();
    setState(() {
      _busy = true;
      _uploadProgress = 0;
      _message = null;
    });
    try {
      final result = await reportService.upload(
        uid: uid,
        bytes: bytes,
        onProgress: (value) {
          if (mounted) setState(() => _uploadProgress = value);
        },
      );
      await telemetry.event('upload_report', {
        'file_size_kb': (bytes.lengthInBytes / 1024).round(),
      });
      setState(() {
        _reportUrl = result.url;
        _message = 'Đã tải lên ${result.path}';
      });
    } catch (error, stack) {
      await telemetry.nonFatal(error, stack, flow: 'report_upload');
      setState(
        () => _message = 'Tải báo cáo thất bại. Dữ liệu vẫn còn để thử lại.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testCrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi crash thử nghiệm?'),
        content: const Text(
          'Ứng dụng sẽ đóng. Mở lại để Crashlytics gửi báo cáo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crash thử'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<FirebaseAppTelemetry>().testCrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<FeatureConfig>();
    final push = context.watch<PushService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Lab 3')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Remote Config', style: Theme.of(context).textTheme.titleLarge),
          Text('Số môn xem trước: ${config.nextCoursePreviewLimit}'),
          Text('Mẹo PE: ${config.enablePeTips ? 'Bật' : 'Tắt'}'),
          if (config.error != null)
            Text(
              config.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton.icon(
            onPressed: config.loading ? null : config.refresh,
            icon: const Icon(Icons.sync),
            label: const Text('Tải cấu hình mới'),
          ),
          const Divider(height: 32),
          Text(
            'Cloud Messaging',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          FilledButton.icon(
            onPressed: () async {
              final telemetry = context.read<FirebaseAppTelemetry>();
              try {
                final settings = await push.requestPermission();
                if (mounted) {
                  setState(
                    () => _message =
                        'Quyền thông báo: ${settings.authorizationStatus.name}',
                  );
                }
              } catch (error, stack) {
                await telemetry.nonFatal(
                  error,
                  stack,
                  flow: 'notification_registration',
                );
                if (mounted) {
                  setState(() => _message =
                      'Không đăng ký được thiết bị nhận thông báo. Vui lòng thử lại.');
                }
              }
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Xin quyền và đăng ký thiết bị'),
          ),
          if (push.token != null)
            Text(
              'Token thiết bị: …${push.token!.substring((push.token!.length - 12).clamp(0, push.token!.length))}',
            ),
          if (push.items.isEmpty)
            const Text('Chưa nhận thông báo trong phiên này.'),
          for (final item in push.items.take(5))
            ListTile(
              leading: Icon(
                item.read
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
              ),
              title: Text(item.title),
              subtitle: Text(item.body),
            ),
          const Divider(height: 32),
          Text(
            'Báo cáo và Cloud Storage',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _createReport,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Tạo PDF từ bảng điểm'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy || _report == null ? null : _upload,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Tải PDF lên Storage'),
          ),
          if (_busy && _uploadProgress > 0)
            LinearProgressIndicator(value: _uploadProgress),
          if (_reportUrl != null)
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(_reportUrl!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Mở URL báo cáo'),
            ),
          const Divider(height: 32),
          Text('Crashlytics', style: Theme.of(context).textTheme.titleLarge),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                throw StateError('Lab 3 non-fatal verification');
              } catch (error, stack) {
                await context.read<FirebaseAppTelemetry>().nonFatal(
                  error,
                  stack,
                  flow: 'lab3_non_fatal_demo',
                );
                if (mounted) {
                  setState(
                    () => _message = 'Đã gửi non-fatal error thử nghiệm.',
                  );
                }
              }
            },
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Gửi non-fatal thử nghiệm'),
          ),
          TextButton(
            onPressed: _testCrash,
            child: const Text('Crash thử nghiệm có xác nhận'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!, semanticsLabel: _message),
            ),
        ],
      ),
    );
  }
}
