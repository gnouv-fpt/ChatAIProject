import 'package:flutter/material.dart';
import '../models/transcript_entry.dart';
import '../services/grade_calculator.dart';
import '../screens/transcript_confirm_screen.dart';

class GradeStrategyWidget extends StatefulWidget {
  final List<TranscriptEntry> currentTranscript;
  final Function(List<TranscriptEntry>) onUpdateTranscript;

  const GradeStrategyWidget({
    super.key,
    required this.currentTranscript,
    required this.onUpdateTranscript,
  });

  @override
  State<GradeStrategyWidget> createState() => _GradeStrategyWidgetState();
}

class _GradeStrategyWidgetState extends State<GradeStrategyWidget> {
  void _simulateScanTranscript() {
    final mockExtracted = [
      TranscriptEntry(courseCode: 'PRF192', score: 8.0, credits: 3, semester: 1, isPassed: true),
      TranscriptEntry(courseCode: 'MAE101', score: 4.0, credits: 3, semester: 1, isPassed: false),
      TranscriptEntry(courseCode: 'MAE101', score: 6.5, credits: 3, semester: 2, isPassed: true),
      TranscriptEntry(courseCode: 'PRO192', score: 7.5, credits: 3, semester: 2, isPassed: true),
      TranscriptEntry(courseCode: 'VOV1', score: 9.0, credits: 2, semester: 1, isPassed: true),
      TranscriptEntry(courseCode: 'PRM392', score: 3.5, credits: 3, semester: 5, isPassed: false, confidence: 0.65),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => TranscriptConfirmScreen(
          rawExtractedEntries: mockExtracted,
          onSaved: (confirmedList) {
            widget.onUpdateTranscript(confirmedList);
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eval = GradeCalculator.evaluateTranscript(widget.currentTranscript);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📊 Bảng điểm & Chiến lược học tập',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _simulateScanTranscript,
                  icon: const Icon(Icons.document_scanner),
                  label: const Text('Import Bảng Điểm (Ảnh)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoBadge('GPA', '${eval.currentGpa}', Colors.indigo),
                const SizedBox(width: 12),
                _buildInfoBadge('Xếp loại', eval.actualRank, Colors.teal),
                const SizedBox(width: 12),
                _buildInfoBadge('Học lại', '${eval.retakeCount} môn', eval.retakeCount >= 2 ? Colors.red : Colors.green),
              ],
            ),
            if (eval.penaltyWarning.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                eval.penaltyWarning,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}