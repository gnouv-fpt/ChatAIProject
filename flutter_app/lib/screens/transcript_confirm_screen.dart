import 'package:flutter/material.dart';
import '../models/transcript_entry.dart';
import '../services/grade_calculator.dart';

class TranscriptConfirmScreen extends StatefulWidget {
  final List<TranscriptEntry> rawExtractedEntries;
  final Function(List<TranscriptEntry>) onSaved;

  const TranscriptConfirmScreen({
    super.key,
    required this.rawExtractedEntries,
    required this.onSaved,
  });

  @override
  State<TranscriptConfirmScreen> createState() => _TranscriptConfirmScreenState();
}

class _TranscriptConfirmScreenState extends State<TranscriptConfirmScreen> {
  late List<TranscriptEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.rawExtractedEntries);
  }

  void _editEntry(int index) {
    final item = _entries[index];
    final codeCtrl = TextEditingController(text: item.courseCode);
    final scoreCtrl = TextEditingController(text: item.score.toString());
    final creditCtrl = TextEditingController(text: item.credits.toString());
    final semCtrl = TextEditingController(text: item.semester.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa thông tin: ${item.courseCode}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Mã môn học'),
              ),
              TextField(
                controller: scoreCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Điểm tổng kết (thang 10)'),
              ),
              TextField(
                controller: creditCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số tín chỉ'),
              ),
              TextField(
                controller: semCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Học kỳ'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final double newScore = double.tryParse(scoreCtrl.text) ?? item.score;
                _entries[index] = TranscriptEntry(
                  courseCode: GradeCalculator.normalizeCode(codeCtrl.text),
                  score: newScore,
                  credits: int.tryParse(creditCtrl.text) ?? item.credits,
                  semester: int.tryParse(semCtrl.text) ?? item.semester,
                  isPassed: newScore >= 5.0,
                  confidence: 1.0,
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eval = GradeCalculator.evaluateTranscript(_entries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận bảng điểm đã quét'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Lưu bảng điểm',
            onPressed: () {
              widget.onSaved(_entries);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã lưu bảng điểm thành công vào máy!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('GPA hiện tại', style: TextStyle(color: Colors.grey)),
                    Text(
                      '${eval.currentGpa}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Xếp loại thực', style: TextStyle(color: Colors.grey)),
                    Text(
                      eval.actualRank,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Học lại', style: TextStyle(color: Colors.grey)),
                    Text(
                      '${eval.retakeCount} môn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: eval.retakeCount >= 2 ? Colors.red : Colors.black87,
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
                style: const TextStyle(color: Colors.brown, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final item = _entries[index];
                final bool isLowConfidence = item.confidence < 0.8;
                final bool isExcluded = GradeCalculator.isExcludedFromGpa(item.courseCode);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: isLowConfidence ? Colors.amber.shade50 : Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isLowConfidence ? Colors.amber : Colors.grey.shade300,
                      width: isLowConfidence ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(
                          item.courseCode,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (isExcluded)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Miễn GPA', style: TextStyle(fontSize: 11, color: Colors.black54)),
                          ),
                        if (isLowConfidence)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Cần kiểm tra', style: TextStyle(fontSize: 11, color: Colors.red)),
                          ),
                      ],
                    ),
                    subtitle: Text('HK${item.semester} • ${item.credits} Tín chỉ • Điểm: ${item.score}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editEntry(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm môn thủ công'),
        onPressed: () {
          final codeCtrl = TextEditingController();
          final scoreCtrl = TextEditingController();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Thêm môn thủ công'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Mã môn')),
                  TextField(controller: scoreCtrl, decoration: const InputDecoration(labelText: 'Điểm')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    if (codeCtrl.text.isNotEmpty) {
                      setState(() {
                        final s = double.tryParse(scoreCtrl.text) ?? 5.0;
                        _entries.add(TranscriptEntry(
                          courseCode: GradeCalculator.normalizeCode(codeCtrl.text),
                          score: s,
                          credits: 3,
                          semester: 1,
                          isPassed: s >= 5.0,
                          confidence: 1.0,
                        ));
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Thêm'),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}