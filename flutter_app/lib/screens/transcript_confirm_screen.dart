import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transcript_entry.dart';
import '../services/grade_calculator.dart';
import '../state/course_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/course_visuals.dart';
import '../widgets/flm_notice.dart';

class TranscriptConfirmScreen extends StatefulWidget {
  final List<TranscriptEntry> rawExtractedEntries;
  final String importWarning;
  final bool manualEntry;
  final Future<void> Function(List<TranscriptEntry>) onSaved;

  const TranscriptConfirmScreen({
    super.key,
    required this.rawExtractedEntries,
    this.importWarning = '',
    this.manualEntry = false,
    required this.onSaved,
  });

  @override
  State<TranscriptConfirmScreen> createState() =>
      _TranscriptConfirmScreenState();
}

class _TranscriptConfirmScreenState extends State<TranscriptConfirmScreen> {
  late List<TranscriptEntry> _entries;
  bool _saving = false;

  bool _missingCredits(TranscriptEntry entry) {
    final course = context.read<CourseCatalog>().findByCode(entry.courseCode);
    return entry.credits == 0 && course != null && course.credits > 0;
  }

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.rawExtractedEntries);
  }

  Future<void> _editEntry([int? index]) async {
    final catalog = context.read<CourseCatalog>();
    final original = index == null ? null : _entries[index];
    final codeController = TextEditingController(
      text: original?.courseCode ?? '',
    );
    final scoreController = TextEditingController(
      text: original?.score.toString() ?? '',
    );
    final semesterController = TextEditingController(
      text: original?.semester.toString() ?? '',
    );
    final creditsController = TextEditingController(
      text: original != null && !_missingCredits(original)
          ? original.credits.toString()
          : '',
    );
    final formKey = GlobalKey<FormState>();
    final edited = await showDialog<TranscriptEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(index == null ? 'Thêm môn học' : 'Sửa môn học'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Mã môn học'),
                    validator: (value) =>
                        catalog.findByCode(value ?? '') == null
                        ? 'Mã môn không có trong chương trình'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: scoreController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Điểm (0–10)'),
                    validator: (value) {
                      final score = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      return score == null || score < 0 || score > 10
                          ? 'Nhập điểm từ 0 đến 10'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: semesterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kỳ (0–20)'),
                    validator: (value) {
                      final semester = int.tryParse(value ?? '');
                      return semester == null || semester < 0 || semester > 20
                          ? 'Nhập kỳ từ 0 đến 20'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: creditsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tín chỉ (để trống dùng chương trình)',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) return null;
                      final credits = int.tryParse(value ?? '');
                      return credits == null || credits < 0 || credits > 30
                          ? 'Nhập tín chỉ từ 0 đến 30'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final course = catalog.findByCode(codeController.text)!;
              final score = double.parse(
                scoreController.text.replaceAll(',', '.'),
              );
              Navigator.pop(
                dialogContext,
                TranscriptEntry(
                  courseCode: course.code,
                  courseName: course.nameVi.isNotEmpty
                      ? course.nameVi
                      : course.name,
                  score: score,
                  credits: creditsController.text.trim().isEmpty
                      ? course.credits
                      : int.parse(creditsController.text),
                  semester: int.parse(semesterController.text),
                  isPassed: original?.inProgress == true ? false : score >= 5,
                  inProgress: original?.inProgress ?? false,
                ),
              );
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 500)).then((_) {
        codeController.dispose();
        scoreController.dispose();
        semesterController.dispose();
        creditsController.dispose();
      }),
    );
    if (!mounted || edited == null) return;
    setState(() {
      if (index == null) {
        _entries.add(edited);
      } else {
        _entries[index] = edited;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final catalog = context.read<CourseCatalog>();
    if (_entries.isEmpty &&
        (!widget.manualEntry || widget.rawExtractedEntries.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có môn học để lưu.')));
      return;
    }
    if (_entries.any(
      (entry) =>
          catalog.findByCode(entry.courseCode) == null ||
          entry.semester < 0 ||
          entry.credits < 0 ||
          entry.score < 0 ||
          entry.score > 10,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hãy sửa mã môn, kỳ, tín chỉ và điểm chưa hợp lệ trước khi lưu.',
          ),
        ),
      );
      return;
    }
    if (_entries.any(_missingCredits)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Có môn chưa xác nhận tín chỉ. Mở dòng được đánh dấu; để trống tín chỉ để dùng chương trình.',
          ),
        ),
      );
      return;
    }
    if (_entries.isEmpty) {
      final clearAll = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xóa toàn bộ bảng điểm?'),
          content: const Text(
            'Bảng điểm đã lưu sẽ bị xóa. Bạn có muốn tiếp tục?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xóa bảng điểm'),
            ),
          ],
        ),
      );
      if (!mounted || clearAll != true) return;
    }
    final confirmed = _entries.map((entry) {
      final course = catalog.findByCode(entry.courseCode)!;
      return TranscriptEntry(
        courseCode: course.code,
        courseName: course.nameVi.isNotEmpty ? course.nameVi : course.name,
        score: entry.score,
        credits: entry.credits,
        semester: entry.semester,
        isPassed: entry.isPassed,
        inProgress: entry.inProgress,
        confidence: entry.confidence,
      );
    }).toList();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSaved(confirmed);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            confirmed.isEmpty ? 'Đã xóa bảng điểm.' : 'Đã lưu bảng điểm.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu bảng điểm. Vui lòng thử lại.'),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eval = GradeCalculator.evaluateTranscript(_entries);
    final hasMissingCredits = _entries.any(_missingCredits);
    final hasGpaCredits = eval.totalGpaCredits > 0 && !hasMissingCredits;

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: Text(
          widget.manualEntry
              ? 'Nhập điểm thủ công'
              : 'Xác nhận bảng điểm đã quét',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Tooltip(
          message: 'Lưu bảng điểm',
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Đang lưu...' : 'Lưu bảng điểm'),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _editEntry(),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm môn thủ công'),
                    ),
                  ),
                ),
                if (widget.importWarning.isNotEmpty || hasMissingCredits)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMd,
                      vertical: AppTheme.spaceSm,
                    ),
                    child: FlmNotice(
                      tone: NoticeTone.warning,
                      message: hasMissingCredits
                          ? 'Có dòng thiếu tín chỉ. Chỉ cần mở các dòng được đánh dấu để kiểm tra trước khi lưu; GPA sẽ tính sau khi bổ sung.'
                          : widget.importWarning,
                    ),
                  ),
                if (_entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.playlist_add_outlined,
                              color: AppTheme.primaryBlue,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Chưa có môn học. Bấm Thêm môn thủ công để bắt đầu.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'GPA hiện tại',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.slate600,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasGpaCredits ? '${eval.currentGpa}' : '—',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Xếp loại thực',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.slate600,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasGpaCredits ? eval.actualRank : 'Chưa tính',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Học lại',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.slate600,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${eval.retakeCount} môn',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: eval.retakeCount >= 2
                                        ? AppTheme.danger
                                        : AppTheme.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (eval.penaltyWarning.isNotEmpty && !hasMissingCredits)
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    child: FlmNotice(
                      message: eval.penaltyWarning,
                      tone: NoticeTone.warning,
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = _entries[index];
                final bool missingCredits = _missingCredits(item);
                final bool isLowConfidence =
                    item.confidence < 0.8 || missingCredits;
                final bool isUnknown =
                    context.watch<CourseCatalog>().findByCode(
                      item.courseCode,
                    ) ==
                    null;
                final bool isExcluded = GradeCalculator.isExcludedFromGpa(
                  item.courseCode,
                );
                final palette = SemesterPalette.of(item.semester);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  color: isLowConfidence || isUnknown
                      ? AppTheme.warningSurface
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isLowConfidence || isUnknown
                          ? AppTheme.warning
                          : AppTheme.slate200,
                      width: isLowConfidence || isUnknown ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: ListTile(
                    onTap: _saving ? null : () => _editEntry(index),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.courseCode,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: palette.fg,
                                ),
                              ),
                            ),
                            if (item.courseName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.courseName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppTheme.slate900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (isUnknown)
                              const Text(
                                'Mã chưa khớp',
                                style: TextStyle(
                                  color: AppTheme.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (isExcluded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.slate100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Miễn GPA',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.slate600,
                                  ),
                                ),
                              ),
                            if (isLowConfidence)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.dangerSurface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  missingCredits
                                      ? 'Kiểm tra tín chỉ'
                                      : 'Cần kiểm tra',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Kỳ ${item.semester} • ${item.credits} tín chỉ • ${item.inProgress ? "Đang học, chưa có điểm cuối" : "Điểm: ${item.score}"}',
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sửa môn học',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: _saving ? null : () => _editEntry(index),
                        ),
                        IconButton(
                          tooltip: 'Xóa môn học',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTheme.danger,
                          ),
                          onPressed: _saving
                              ? null
                              : () {
                                  setState(() {
                                    _entries.removeAt(index);
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: _entries.length),
            ),
          ),
        ],
      ),
    );
  }
}
