import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_launcher.dart';
import '../models/load_status.dart';
import '../models/transcript_entry.dart';
import '../state/course_catalog.dart';
import '../state/transcript_import_view_model.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/course_visuals.dart';
import '../widgets/data_state_view.dart';
import '../widgets/m3_components.dart';
import 'transcript_confirm_screen.dart';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});

  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  String _selectedFilter = 'all'; // 'all' | 'passed' | 'failed' | 'in_progress'

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

  Future<void> _deleteEntry(TranscriptEntry entry) async {
    final provider = context.read<TranscriptProvider>();
    final current = List<TranscriptEntry>.from(provider.entries);
    final index = current.indexWhere((e) => e.courseCode == entry.courseCode);
    if (index == -1) return;
    final removed = current.removeAt(index);
    await provider.save(current);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xóa môn ${entry.courseCode}'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () async {
            current.insert(index, removed);
            await provider.save(current);
          },
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _quickEdit(TranscriptEntry entry) async {
    final scoreController = TextEditingController(
      text: entry.inProgress ? '' : entry.score.toStringAsFixed(1),
    );
    bool inProgress = entry.inProgress;
    final formKey = GlobalKey<FormState>();
    final updated = await showDialog<TranscriptEntry>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Sửa điểm môn ${entry.courseCode}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: inProgress,
                  title: const Text('Đang học kỳ này'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => inProgress = val ?? false),
                ),
                if (!inProgress)
                  TextFormField(
                    controller: scoreController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Điểm (0–10)',
                      hintText: 'Ví dụ: 8.5',
                    ),
                    validator: (v) {
                      final num = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (num == null || num < 0 || num > 10) return 'Nhập điểm từ 0 đến 10';
                      return null;
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (!inProgress && !formKey.currentState!.validate()) return;
                final score = inProgress
                    ? 0.0
                    : double.parse(scoreController.text.replaceAll(',', '.'));
                final isPassed = inProgress ? false : score >= 5.0;
                Navigator.pop(
                  ctx,
                  TranscriptEntry(
                    courseCode: entry.courseCode,
                    courseName: entry.courseName,
                    score: score,
                    credits: entry.credits,
                    semester: entry.semester,
                    isPassed: isPassed,
                    inProgress: inProgress,
                  ),
                );
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (updated != null && mounted) {
      final provider = context.read<TranscriptProvider>();
      final current = List<TranscriptEntry>.from(provider.entries);
      final idx = current.indexWhere((e) => e.courseCode == entry.courseCode);
      if (idx != -1) {
        current[idx] = updated;
        await provider.save(current);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transcript = context.watch<TranscriptProvider>();
    final importer = context.watch<TranscriptImportViewModel>();
    final catalog = context.watch<CourseCatalog>();
    final colorScheme = Theme.of(context).colorScheme;

    // Loading State
    if (transcript.status == LoadStatus.loading) {
      return Scaffold(
        appBar: const FlmAppBar(
          title: 'Bảng điểm',
          subtitle: 'GPA và tiến độ học tập cá nhân',
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: const [
            SkeletonCard(height: 140),
            SizedBox(height: 16),
            SkeletonBox(height: 44, borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMd))),
            SizedBox(height: 12),
            SkeletonBox(height: 72, borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMd))),
            SizedBox(height: 10),
            SkeletonBox(height: 72, borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMd))),
            SizedBox(height: 10),
            SkeletonBox(height: 72, borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMd))),
          ],
        ),
      );
    }

    // Error State
    if (transcript.status == LoadStatus.error) {
      return Scaffold(
        appBar: const FlmAppBar(
          title: 'Bảng điểm',
          subtitle: 'GPA và tiến độ học tập cá nhân',
        ),
        body: DataStateView(
          status: transcript.status,
          message: transcript.loadError,
          onRetry: transcript.load,
        ),
      );
    }

    final entries = transcript.sortedEntries;
    final totalCredits = catalog.curriculum?.totalCredits ?? 147;
    final totalCourses = catalog.courses.isNotEmpty ? catalog.courses.length : 48;
    final passedCount = entries.where((e) => e.isPassed).length;
    final failedCount = entries.where((e) => !e.isPassed && !e.inProgress).length;
    final inProgressCount = entries.where((e) => e.inProgress).length;

    return Scaffold(
      appBar: FlmAppBar(
        title: 'Bảng điểm',
        subtitle: 'GPA và tiến độ học tập cá nhân',
        actions: [
          // Small sync status icon with tooltip (only when transcript has data)
          if (transcript.hasTranscript)
            IconButton(
              icon: Icon(
                transcript.usesCloud ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                size: 20,
                color: transcript.usesCloud ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              tooltip: transcript.usesCloud
                  ? 'Đã đồng bộ bảo mật với tài khoản'
                  : 'Lưu riêng tư trên thiết bị',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      transcript.usesCloud
                          ? 'Dữ liệu được bảo mật và đồng bộ theo tài khoản'
                          : 'Dữ liệu chỉ lưu riêng tư trên thiết bị này',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ContextualChatLauncher(
            curriculumId: catalog.curriculum?.id ?? '',
            contextKey: 'transcript',
            title: 'bảng điểm',
            contextHint: 'Bảng điểm và GPA cá nhân trong chương trình ${catalog.curriculum?.id ?? ''}',
            suggestedQuestions: const [
              'GPA hiện tại của tôi là bao nhiêu?',
              'Tôi nên cải thiện điểm những môn nào?',
              'Quy định về hạ bậc tốt nghiệp?',
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          // 1. OCR Importer in Progress
          if (importer.busy) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Đang nhận diện bảng điểm bằng AI OCR...',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: const LinearProgressIndicator(minHeight: 4),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 2. Importer Error Notice
          if (importer.message != null) ...[
            InlineBanner(
              message: importer.message!,
              severity: BannerSeverity.error,
              onDismiss: () {},
            ),
            const SizedBox(height: 12),
          ],

          // 3. EMPTY STATE (When no transcript exists)
          if (!transcript.hasTranscript) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: Icons.description_outlined,
                title: 'Chưa có bảng điểm',
                description: 'Nhập ảnh hoặc điểm thủ công để theo dõi GPA và kiểm tra điều kiện tiên quyết.',
                actionLabel: 'Nhập ảnh bảng điểm',
                onAction: importer.busy ? null : _import,
              ),
            ),
            Center(
              child: OutlinedButton.icon(
                onPressed: importer.busy ? null : _editManually,
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text('Nhập điểm thủ công'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(220, 44),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Dữ liệu được lưu trữ an toàn trên thiết bị của bạn',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ] else ...[
            // 4. POPULATED STATE: SummaryCard
            SummaryCard(
              title: 'Điểm trung bình tích lũy (GPA)',
              subtitle: 'Mục tiêu: ${transcript.targetGpa.toStringAsFixed(1)} / 10',
              metrics: [
                SummaryMetric(
                  label: 'GPA hiện tại',
                  value: transcript.evaluation.currentGpa.toStringAsFixed(2),
                ),
                SummaryMetric(
                  label: 'Tín chỉ',
                  value: '${transcript.evaluation.totalAccumulatedCredits}/$totalCredits',
                ),
                SummaryMetric(
                  label: 'Đã đạt',
                  value: '$passedCount/$totalCourses môn',
                ),
                SummaryMetric(
                  label: 'Xếp loại',
                  value: transcript.evaluation.actualRank,
                ),
              ],
              actionLabel: 'Cập nhật',
              onAction: importer.busy ? null : _editManually,
            ),

            if (transcript.evaluation.penaltyWarning.isNotEmpty) ...[
              const SizedBox(height: 12),
              InlineBanner(
                message: transcript.evaluation.penaltyWarning,
                severity: BannerSeverity.warning,
              ),
            ],

            const SizedBox(height: 16),

            // Import CTA Bar
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: importer.busy ? null : _import,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Quét ảnh mới'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: importer.busy ? null : _editManually,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Sửa điểm'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('Tất cả (${entries.length})'),
                    selected: _selectedFilter == 'all',
                    onSelected: (val) => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Đạt ($passedCount)'),
                    selected: _selectedFilter == 'passed',
                    onSelected: (val) => setState(() => _selectedFilter = 'passed'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Chưa đạt ($failedCount)'),
                    selected: _selectedFilter == 'failed',
                    onSelected: (val) => setState(() => _selectedFilter = 'failed'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Đang học ($inProgressCount)'),
                    selected: _selectedFilter == 'in_progress',
                    onSelected: (val) => setState(() => _selectedFilter = 'in_progress'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Grouped Courses by Semester
            ..._buildSemesterGroups(context, entries),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSemesterGroups(BuildContext context, List<TranscriptEntry> allEntries) {
    final filtered = allEntries.where((entry) {
      if (_selectedFilter == 'passed') return entry.isPassed;
      if (_selectedFilter == 'failed') return !entry.isPassed && !entry.inProgress;
      if (_selectedFilter == 'in_progress') return entry.inProgress;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: EmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'Không có môn học phù hợp',
            description: 'Thử chuyển sang bộ lọc khác để xem danh sách môn.',
          ),
        ),
      ];
    }

    final groups = <int, List<TranscriptEntry>>{};
    for (final entry in filtered) {
      groups.putIfAbsent(entry.semester, () => []).add(entry);
    }
    final sortedSemesters = groups.keys.toList()..sort();

    final widgets = <Widget>[];
    for (final sem in sortedSemesters) {
      final list = groups[sem]!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: SectionHeader(
            title: 'Học kỳ $sem · ${list.length} môn',
          ),
        ),
      );
      for (final entry in list) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DismissibleEntryTile(
              entry: entry,
              onEdit: () => _quickEdit(entry),
              onDelete: () => _deleteEntry(entry),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _DismissibleEntryTile extends StatelessWidget {
  const _DismissibleEntryTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final TranscriptEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = SemesterPalette.of(entry.semester);

    final statusWidget = entry.inProgress
        ? StatusChip.info(label: 'Đang học')
        : entry.isPassed
            ? StatusChip.success(label: 'Đạt (${entry.score.toStringAsFixed(1)})')
            : StatusChip.error(label: 'Chưa đạt (${entry.score.toStringAsFixed(1)})');

    return Dismissible(
      key: Key('transcript_entry_${entry.courseCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                IconTile(
                  icon: courseIcon(entry.courseCode),
                  color: palette.fg,
                  background: palette.bg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.courseCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.courseName.isNotEmpty ? entry.courseName : 'Môn học',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.credits} tín chỉ · Học kỳ ${entry.semester}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    statusWidget,
                    const SizedBox(height: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Sửa điểm',
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
