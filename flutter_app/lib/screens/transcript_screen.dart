import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/providers/chat_provider.dart';
import '../models/transcript_entry.dart';
import '../services/grade_import_service.dart';
import '../state/transcript_provider.dart';
import 'transcript_confirm_screen.dart';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  bool _importing = false;
  String? _error;

  Future<void> _import() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      allowMultiple: true,
      withData: true,
    );
    if (!mounted || selected == null) return;
    if (selected.files.isEmpty || selected.files.length > 10) {
      setState(() => _error = 'Chọn từ 1 đến 10 ảnh bảng điểm.');
      return;
    }
    final images = <ImageFile>[];
    for (final file in selected.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(
          () => _error = 'Không thể đọc ảnh ${file.name}. Vui lòng chọn lại.',
        );
        return;
      }
      images.add(
        ImageFile(
          filename: file.name,
          bytes: bytes,
          mimeType: file.extension?.toLowerCase() == 'png'
              ? 'image/png'
              : 'image/jpeg',
        ),
      );
    }
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final baseUrl = context.read<ChatProvider>().baseUrl;
      final result = await GradeImportService(baseUrl: baseUrl)
          .importFromImages(images);
      if (!mounted) return;
      if (result.entries.isEmpty) {
        setState(
          () =>
              _error = 'Không đọc được môn học nào từ ảnh. Hãy thử ảnh rõ hơn.',
        );
        return;
      }
      final provider = context.read<TranscriptProvider>();
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => TranscriptConfirmScreen(
            rawExtractedEntries: _mergeEntries(
              provider.entries,
              result.entries,
            ),
            importWarning: result.warning,
            onSaved: (entries) => provider.save(entries),
          ),
        ),
      );
    } on GradeImportException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể xử lý ảnh. Vui lòng thử lại hoặc nhập tay.',
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  List<TranscriptEntry> _mergeEntries(
    List<TranscriptEntry> saved,
    List<TranscriptEntry> imported,
  ) {
    final merged = List<TranscriptEntry>.from(saved);
    for (final entry in imported) {
      final index = merged.indexWhere(
        (old) =>
            old.courseCode == entry.courseCode &&
            old.semester == entry.semester,
      );
      if (index == -1) {
        merged.add(entry);
      } else {
        merged[index] = entry;
      }
    }
    return merged;
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
    final entries = transcript.entries.toList()
      ..sort((a, b) {
        final semester = b.semester.compareTo(a.semester);
        return semester != 0 ? semester : a.courseCode.compareTo(b.courseCode);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điểm')),
      body: !transcript.isLoaded
          ? const Center(child: CircularProgressIndicator())
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
                const Text(
                  'Ảnh được gửi tới backend chỉ để đọc điểm và không được lưu trên máy chủ. Bảng điểm đã xác nhận chỉ lưu trên thiết bị này.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    _importing ? 'Đang đọc bảng điểm...' : 'Nhập ảnh bảng điểm',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _importing ? null : _editManually,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Nhập hoặc sửa điểm thủ công'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
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
