import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transcript_entry.dart';
import '../services/grade_calculator.dart';
import '../state/course_catalog.dart';

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
    final formKey = GlobalKey<FormState>();
    final edited = await showDialog<TranscriptEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(index == null ? 'Thêm môn học' : 'Sửa môn học'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Mã môn học'),
                  validator: (value) => catalog.findByCode(value ?? '') == null
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
                  decoration: const InputDecoration(labelText: 'Học kỳ đã học'),
                  validator: (value) {
                    final semester = int.tryParse(value ?? '');
                    return semester == null || semester < 1 || semester > 20
                        ? 'Nhập học kỳ từ 1 đến 20'
                        : null;
                  },
                ),
              ],
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
                  credits: course.credits,
                  semester: int.parse(semesterController.text),
                  isPassed: score >= 5,
                ),
              );
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
    // showDialog completes when pop starts; its reverse transition still owns
    // the TextFormFields for a few frames. Dispose after the route is gone.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 500)).then((_) {
        codeController.dispose();
        scoreController.dispose();
        semesterController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có môn học để lưu.')),
      );
      return;
    }
    if (_entries.any(
          (entry) =>
              catalog.findByCode(entry.courseCode) == null ||
              entry.semester < 1 ||
              entry.score < 0 ||
              entry.score > 10,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hãy sửa mã môn, học kỳ và điểm chưa hợp lệ trước khi lưu.',
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
          content: const Text('Các môn đã lưu sẽ bị xóa khỏi thiết bị này.'),
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
        credits: course.credits,
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
          content: Text(confirmed.isEmpty
              ? 'Đã xóa bảng điểm khỏi máy.'
              : 'Đã lưu bảng điểm vào máy.'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.manualEntry
              ? 'Nhập điểm thủ công'
              : 'Xác nhận bảng điểm đã quét',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Lưu bảng điểm',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _editEntry(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm môn thủ công'),
              ),
            ),
          ),
          if (widget.importWarning.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.amber.shade100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade900,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.importWarning,
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có môn học. Bấm Thêm môn thủ công để bắt đầu.'),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.indigo.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'GPA hiện tại',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '${eval.currentGpa}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Xếp loại thực',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        eval.actualRank,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Học lại',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '${eval.retakeCount} môn',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: eval.retakeCount >= 2
                              ? Colors.red
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (eval.penaltyWarning.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade100,
              child: Text(
                eval.penaltyWarning,
                style: const TextStyle(
                  color: Colors.brown,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final item = _entries[index];
                final bool isLowConfidence = item.confidence < 0.8;
                final bool isUnknown =
                    context.read<CourseCatalog>().findByCode(item.courseCode) ==
                        null ||
                    item.semester < 1;
                final bool isExcluded = GradeCalculator.isExcludedFromGpa(
                  item.courseCode,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: isLowConfidence || isUnknown
                      ? Colors.amber.shade50
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isLowConfidence || isUnknown
                          ? Colors.amber
                          : Colors.grey.shade300,
                      width: isLowConfidence || isUnknown ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    onTap: () => _editEntry(index),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.courseCode,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isUnknown)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Mã chưa khớp',
                              style: TextStyle(color: Colors.red, fontSize: 11),
                            ),
                          ),
                        if (isExcluded)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Miễn GPA',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        if (isLowConfidence)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Cần kiểm tra',
                              style: TextStyle(fontSize: 11, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      'HK${item.semester} • ${item.credits} Tín chỉ • ${item.inProgress ? "Đang học, chưa có điểm cuối" : "Điểm: ${item.score}"}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sửa môn học',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editEntry(index),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            setState(() {
                              _entries.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
