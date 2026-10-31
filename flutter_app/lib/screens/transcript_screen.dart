import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/transcript_import_view_model.dart';
import '../models/load_status.dart';
import '../models/transcript_entry.dart';
import '../widgets/app_ui.dart';
import '../features/chat/views/widgets/contextual_chat_launcher.dart';
import '../state/course_catalog.dart';
import '../widgets/course_visuals.dart';
import '../widgets/data_state_view.dart';
import '../widgets/flm_notice.dart';
import '../theme/app_theme.dart';
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
    final hasGpa =
        transcript.hasTranscript && transcript.evaluation.totalGpaCredits > 0;
    return Scaffold(
      appBar: FlmAppBar(
        title: 'Bảng điểm',
        subtitle: 'GPA và tiến độ học tập cá nhân',
        actions: [
          ContextualChatLauncher(
            curriculumId: context.watch<CourseCatalog>().curriculum?.id ?? '',
            contextKey: 'transcript',
            title: 'bảng điểm',
            contextHint: 'Bảng điểm và GPA cá nhân trong chương trình ${context.read<CourseCatalog>().curriculum?.id ?? ''}',
            suggestedQuestions: const [
              'GPA hiện tại của tôi là bao nhiêu?',
              'Tôi nên cải thiện điểm những môn nào?',
            ],
          ),
        ],
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                HeroPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'GPA hiện tại',
                              style: TextStyle(
                                color: Color(0xFFE3F2FD),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              transcript.usesCloud ? 'ĐỒNG BỘ' : 'CÁ NHÂN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasGpa
                            ? transcript.evaluation.currentGpa
                                  .toStringAsFixed(2)
                            : 'Chưa đủ dữ liệu GPA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: hasGpa ? 40 : 24,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      if (transcript.hasTranscript) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: HeroStat(
                                value:
                                    '${transcript.evaluation.totalAccumulatedCredits}',
                                label: 'Tín chỉ tích lũy',
                              ),
                            ),
                            Expanded(
                              child: HeroStat(
                                value: '${entries.length}',
                                label: 'Môn đã nhập',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${transcript.evaluation.totalAccumulatedCredits} tín chỉ tích lũy · ${transcript.evaluation.actualRank}',
                          style: const TextStyle(color: Color(0xFFE3F2FD)),
                        ),
                        if (transcript.evaluation.penaltyWarning.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: StatusPill(
                              label: transcript.evaluation.penaltyWarning,
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.warning,
                              background: AppTheme.warningSurface,
                            ),
                          ),
                      ] else ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Nhập ảnh hoặc điểm thủ công để tính GPA.',
                          style: TextStyle(color: Color(0xFFE3F2FD)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                  FlmNotice(message: importer.message!, tone: NoticeTone.error),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: AppTheme.slate600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        transcript.usesCloud
                            ? 'Ảnh được gửi tới backend để đọc điểm. Chỉ bảng điểm đã xác nhận được lưu trên Firestore theo tài khoản; không lưu ảnh trên Firestore.'
                            : 'Ảnh được gửi tới backend chỉ để đọc điểm và không được lưu trên máy chủ. Bảng điểm đã xác nhận chỉ lưu trên thiết bị này.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.slate600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Các môn đã nhập'),
                if (entries.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const IconTile(
                            icon: Icons.description_rounded,
                            color: AppTheme.primaryBlue,
                            size: 56,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Chưa có bảng điểm. Nhập ảnh hoặc nhập điểm thủ công để xem GPA và tiến độ.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EntryTile(entry: entry),
                  ),
              ],
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final TranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = SemesterPalette.of(entry.semester);
    final (Color fg, Color bg, String label) = entry.inProgress
        ? (AppTheme.primaryDark, AppTheme.primaryLight, 'Đang học')
        : entry.isPassed
        ? (AppTheme.success, AppTheme.successSurface, 'Đạt')
        : (AppTheme.danger, AppTheme.dangerSurface, 'Chưa đạt');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        leading: IconTile(
          icon: courseIcon(entry.courseCode),
          color: palette.fg,
          background: palette.bg,
        ),
        title: Text(
          '${entry.courseCode} · ${entry.courseName.isNotEmpty ? entry.courseName : 'Môn học'}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          '${entry.credits} tín chỉ · Học kỳ ${entry.semester}',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 60),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.inProgress ? '—' : entry.score.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
