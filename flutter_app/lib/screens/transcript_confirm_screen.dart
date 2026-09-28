import 'package:flutter/material.dart';
import '../models/transcript_entry.dart';
import '../services/grade_calculator.dart';

class TranscriptConfirmScreen extends StatefulWidget {
  final List<TranscriptEntry> rawExtractedEntries;
  final String importWarning;
  final Function(List<TranscriptEntry>) onSaved;

  const TranscriptConfirmScreen({
    super.key,
    required this.rawExtractedEntries,
    this.importWarning = '',
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
          if (widget.importWarning.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.amber.shade100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.importWarning,
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
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
    );
  }
}
