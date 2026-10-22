import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/transcript_import_view_model.dart';
import '../models/load_status.dart';
import '../widgets/data_state_view.dart';
import '../state/transcript_provider.dart';
import 'transcript_confirm_screen.dart';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  Future<void> _import() async {
    final importer = context.read<TranscriptImportViewModel>();
    final result = await importer.import();
    if (!mounted || result == null) return;
    final provider = context.read<TranscriptProvider>();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TranscriptConfirmScreen(
          rawExtractedEntries: importer.merge(provider.entries, result.entries),
          importWarning: result.warning,
          onSaved: provider.save,
        ),
      ),
    );
  }

  Future<void> _editManually() async {
    final provider = context.read<TranscriptProvider>();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TranscriptConfirmScreen(
          rawExtractedEntries: provider.entries,
          manualEntry: true,
          onSaved: (entries) => provider.save(entries),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transcript = context.watch<TranscriptProvider>();
    final importer = context.watch<TranscriptImportViewModel>();
    final entries = transcript.sortedEntries;
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điểm')),
      body:
          transcript.status == LoadStatus.loading ||
              transcript.status == LoadStatus.error
          ? DataStateView(
              status: transcript.status,
              message: transcript.loadError,
              onRetry: transcript.status == LoadStatus.error
                  ? transcript.load
                  : null,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GPA hiện tại',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          transcript.hasTranscript
                              ? transcript.evaluation.currentGpa
                                    .toStringAsFixed(2)
                              : 'Chưa có dữ liệu',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (transcript.hasTranscript) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${transcript.evaluation.totalAccumulatedCredits} tín chỉ tích lũy · ${transcript.evaluation.actualRank}',
                          ),
                          if (transcript.evaluation.penaltyWarning.isNotEmpty)
                            Text(
                              transcript.evaluation.penaltyWarning,
                              style: TextStyle(color: Colors.orange.shade800),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  transcript.usesCloud
                      ? 'Ảnh được gửi tới backend để đọc điểm. Chỉ bảng điểm đã xác nhận được lưu trên Firestore theo tài khoản; không lưu ảnh trên Firestore.'
                      : 'Ảnh được gửi tới backend chỉ để đọc điểm và không được lưu trên máy chủ. Bảng điểm đã xác nhận chỉ lưu trên thiết bị này.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: importer.busy ? null : _import,
                  icon: importer.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    importer.busy
                        ? 'Đang đọc bảng điểm...'
                        : 'Nhập ảnh bảng điểm',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: importer.busy ? null : _editManually,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Nhập hoặc sửa điểm thủ công'),
                ),
                if (importer.message != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        importer.message!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Các môn đã nhập',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Chưa có bảng điểm. Nhập ảnh hoặc nhập điểm thủ công để xem GPA và tiến độ.',
                    ),
                  ),
                for (final entry in entries)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${entry.semester}')),
                      title: Text(
                        '${entry.courseCode} · ${entry.courseName.isNotEmpty ? entry.courseName : 'Môn học'}',
                      ),
                      subtitle: Text(
                        '${entry.credits} tín chỉ · Học kỳ ${entry.semester}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.inProgress
                                ? '—'
                                : entry.score.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            entry.inProgress
                                ? 'Đang học'
                                : entry.isPassed
                                ? 'Đạt'
                                : 'Chưa đạt',
                            style: TextStyle(
                              fontSize: 14,
                              color: entry.inProgress
                                  ? Colors.blue.shade700
                                  : entry.isPassed
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
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
