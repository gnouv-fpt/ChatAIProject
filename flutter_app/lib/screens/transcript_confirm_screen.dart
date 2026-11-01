import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transcript_entry.dart';
import '../services/grade_calculator.dart';
import '../state/course_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/course_visuals.dart';
import '../widgets/m3_components.dart';

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
  bool _isDirty = false;

  bool _missingCredits(TranscriptEntry entry) {
    final course = context.read<CourseCatalog>().findByCode(entry.courseCode);
    return entry.credits == 0 && course != null && course.credits > 0;
  }

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.rawExtractedEntries);
    // If imported from OCR, mark dirty by default so user doesn't accidentally exit without saving
    _isDirty = widget.rawExtractedEntries.isNotEmpty && !widget.manualEntry;
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_isDirty && _entries.length == widget.rawExtractedEntries.length) {
      return true;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát mà không lưu?'),
        content: const Text(
          'Các môn học đã quét hoặc thay đổi sẽ không được lưu vào bảng điểm cá nhân.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  Future<void> _editEntry([int? index]) async {
    final catalog = context.read<CourseCatalog>();
    final original = index == null ? null : _entries[index];
    final codeController = TextEditingController(
      text: original?.courseCode ?? '',
    );
    final scoreController = TextEditingController(
      text: original != null
          ? (original.inProgress ? '' : original.score.toStringAsFixed(1))
          : '',
    );
    final semesterController = TextEditingController(
      text: original?.semester.toString() ?? '',
    );
    final creditsController = TextEditingController(
      text: original != null && !_missingCredits(original)
          ? original.credits.toString()
          : '',
    );
    bool inProgress = original?.inProgress ?? false;
    final formKey = GlobalKey<FormState>();

    final edited = await showDialog<TranscriptEntry>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(index == null ? 'Thêm môn học' : 'Sửa thông tin môn'),
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
                      decoration: const InputDecoration(
                        labelText: 'Mã môn học',
                        hintText: 'Ví dụ: PRM392',
                      ),
                      validator: (value) =>
                          catalog.findByCode(value ?? '') == null
                              ? 'Mã môn không có trong chương trình'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: inProgress,
                      title: const Text('Đang học kỳ này'),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() => inProgress = val ?? false);
                      },
                    ),
                    if (!inProgress) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: scoreController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Điểm (0–10)',
                          hintText: 'Ví dụ: 8.5',
                        ),
                        validator: (value) {
                          final score = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );
                          return score == null || score < 0 || score > 10
                              ? 'Nhập điểm từ 0 đến 10'
                              : null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: semesterController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Học kỳ (0–20)',
                        hintText: 'Ví dụ: 5',
                      ),
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
                final score = inProgress
                    ? 0.0
                    : double.parse(scoreController.text.replaceAll(',', '.'));
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
                    isPassed: inProgress ? false : score >= 5,
                    inProgress: inProgress,
                    // If manually edited, confidence becomes 1.0 (verified)
                    confidence: 1.0,
                  ),
                );
              },
              child: const Text('Áp dụng'),
            ),
          ],
        ),
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
      _isDirty = true;
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
      _isDirty = false;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            confirmed.isEmpty ? 'Đã xóa bảng điểm.' : 'Đã lưu bảng điểm thành công.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu bảng điểm. Vui lòng thử lại.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final eval = GradeCalculator.evaluateTranscript(_entries);
    final hasMissingCredits = _entries.any(_missingCredits);
    final hasGpaCredits = eval.totalGpaCredits > 0 && !hasMissingCredits;

    final lowConfidenceCount = _entries.where((e) => e.confidence < 0.85 || _missingCredits(e)).length;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscardChanges();
        if (shouldLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _saving
                    ? 'Đang lưu bảng điểm...'
                    : 'Xác nhận & Lưu bảng điểm (${_entries.length} môn)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    // Manual Add Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _editEntry(),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Thêm môn thủ công'),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Warnings
                    if (widget.importWarning.isNotEmpty || hasMissingCredits) ...[
                      InlineBanner(
                        message: hasMissingCredits
                            ? 'Có môn thiếu số tín chỉ. Vui lòng mở dòng được đánh dấu để bổ sung trước khi lưu.'
                            : widget.importWarning,
                        severity: BannerSeverity.warning,
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (lowConfidenceCount > 0 && !hasMissingCredits) ...[
                      InlineBanner(
                        message: 'AI phát hiện $lowConfidenceCount môn có độ tin cậy thấp. Vui lòng chạm vào môn để đối chiếu điểm và mã môn.',
                        severity: BannerSeverity.info,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Evaluation Summary Card
                    if (_entries.isNotEmpty) ...[
                      SummaryCard(
                        title: 'Đánh giá sơ bộ sau khi lưu',
                        subtitle: 'Dựa trên ${_entries.length} môn học đã quét',
                        metrics: [
                          SummaryMetric(
                            label: 'GPA dự kiến',
                            value: hasGpaCredits ? eval.currentGpa.toStringAsFixed(2) : '—',
                          ),
                          SummaryMetric(
                            label: 'Xếp loại',
                            value: hasGpaCredits ? eval.actualRank : 'Chưa tính',
                          ),
                          SummaryMetric(
                            label: 'Học lại',
                            value: '${eval.retakeCount} môn',
                          ),
                          SummaryMetric(
                            label: 'Cần kiểm tra',
                            value: '$lowConfidenceCount môn',
                          ),
                        ],
                      ),
                      if (eval.penaltyWarning.isNotEmpty && !hasMissingCredits) ...[
                        const SizedBox(height: 10),
                        InlineBanner(
                          message: eval.penaltyWarning,
                          severity: BannerSeverity.warning,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            if (_entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: EmptyState(
                    icon: Icons.playlist_add_rounded,
                    title: 'Chưa có môn học',
                    description: 'Bấm nút "Thêm môn thủ công" ở trên để bắt đầu nhập bảng điểm.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _entries[index];
                    final bool missingCredits = _missingCredits(item);
                    final bool isLowConfidence = item.confidence < 0.85 || missingCredits;
                    final bool isUnknown = context
                            .watch<CourseCatalog>()
                            .findByCode(item.courseCode) ==
                        null;
                    final bool isExcluded = GradeCalculator.isExcludedFromGpa(
                      item.courseCode,
                    );
                    final palette = SemesterPalette.of(item.semester);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          side: BorderSide(
                            color: isLowConfidence || isUnknown
                                ? colorScheme.error.withValues(alpha: 0.6)
                                : colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: isLowConfidence || isUnknown ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          onTap: _saving ? null : () => _editEntry(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                IconTile(
                                  icon: courseIcon(item.courseCode),
                                  color: palette.fg,
                                  background: palette.bg,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item.courseCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isLowConfidence)
                                            StatusChip.warning(
                                              label: missingCredits
                                                  ? 'Thiếu tín chỉ'
                                                  : 'Cần kiểm tra',
                                            )
                                          else
                                            StatusChip.success(
                                              label: 'Tin cậy',
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.courseName.isNotEmpty
                                            ? item.courseName
                                            : 'Môn học',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'Kỳ ${item.semester} · ${item.credits} tín chỉ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurfaceVariant
                                                  .withValues(alpha: 0.8),
                                            ),
                                          ),
                                          if (isExcluded)
                                            StatusChip.info(
                                              label: 'Miễn GPA',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (item.inProgress)
                                      StatusChip.info(label: 'Đang học')
                                    else if (item.isPassed)
                                      StatusChip.success(
                                        label: 'Đạt (${item.score.toStringAsFixed(1)})',
                                      )
                                    else
                                      StatusChip.error(
                                        label: 'Trượt (${item.score.toStringAsFixed(1)})',
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Sửa môn học',
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _saving
                                              ? null
                                              : () => _editEntry(index),
                                        ),
                                        IconButton(
                                          tooltip: 'Xóa môn học',
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: colorScheme.error,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _saving
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _isDirty = true;
                                                    _entries.removeAt(index);
                                                  });
                                                },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: _entries.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
