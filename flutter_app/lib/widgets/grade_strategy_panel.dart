import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';

/// Widget "Bảng điểm & Chiến lược" đặt ở Tab Tổng quan của Màn 2.
/// Hiển thị GPA, xếp loại và cảnh báo hạ bậc từ bảng điểm đã xác nhận trong chat.
/// Mục 7.1, 7.2, 7.3 — dữ kiện tính bằng code (GradeCalculator), không qua LLM.
class GradeStrategyPanel extends StatefulWidget {
  final String curriculumId;
  final ValueChanged<String>? onAdvisorPrompt;

  const GradeStrategyPanel({super.key, required this.curriculumId, this.onAdvisorPrompt});

  @override
  State<GradeStrategyPanel> createState() => _GradeStrategyPanelState();
}

class _GradeStrategyPanelState extends State<GradeStrategyPanel> {
  void _showTargetGpaDialog(BuildContext ctx, double current) {
    final tp = context.read<TranscriptProvider>();
    double draft = tp.targetGpa;
    showDialog<void>(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (sCtx, setSt) => AlertDialog(
          title: const Text('Đặt mục tiêu GPA tốt nghiệp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GPA hiện tại: $current',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Slider(
                value: draft,
                min: current.clamp(0.0, 9.9),
                max: 10.0,
                divisions: 20,
                label: draft.toStringAsFixed(1),
                onChanged: (v) => setSt(() => draft = v),
              ),
              Text(
                'Mục tiêu: ${draft.toStringAsFixed(1)}  (${_rankFor(draft)})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                tp.setTargetGpa(draft);
                Navigator.pop(dCtx);
              },
              child: const Text('Lưu mục tiêu'),
            ),
          ],
        ),
      ),
    );
  }

  String _rankFor(double gpa) {
    if (gpa >= 9.0) return 'Xuất sắc';
    if (gpa >= 8.0) return 'Giỏi';
    if (gpa >= 6.5) return 'Khá';
    if (gpa >= 5.0) return 'Trung bình';
    return 'Không đạt';
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TranscriptProvider>();
    final hasData = tp.hasTranscript;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Bảng điểm & Chiến lược Học tập',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
              // Import button
              _buildTranscriptMenuButton(context),
            ],
          ),

          const SizedBox(height: 14),

          if (!hasData) _buildEmptyState(context) else _buildGpaStats(context, tp),
        ],
      ),
    );
  }

  Widget _buildTranscriptMenuButton(BuildContext ctx) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'clear') context.read<TranscriptProvider>().clearTranscript();
      },
      itemBuilder: (_) => [
        if (context.read<TranscriptProvider>().hasTranscript)
          const PopupMenuItem(
            value: 'clear',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Xóa bảng điểm', style: TextStyle(color: Colors.red)),
            ]),
          ),
      ],
      child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.upload_file_outlined, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Quản lý điểm',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext ctx) {
    return Column(
      children: [
        Text(
          'Gửi ảnh bảng điểm ngay trong khung chat để AI đọc, xác nhận và phân tích chiến lược các kỳ tiếp theo.',
          style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFeatureChip(Icons.calculate_outlined, 'GPA chính xác'),
            const SizedBox(width: 8),
            _buildFeatureChip(Icons.warning_amber_outlined, 'Cảnh báo hạ bậc'),
            const SizedBox(width: 8),
            _buildFeatureChip(Icons.school_outlined, 'Tư vấn lộ trình'),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Mở Chat AI và bấm biểu tượng ảnh cạnh ô nhập tin nhắn để gửi bảng điểm.',
          style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF92400E))),
        ],
      ),
    );
  }

  Widget _buildGpaStats(BuildContext ctx, TranscriptProvider tp) {
    final eval = tp.evaluation;
    // Tính tín chỉ còn lại từ CourseCatalog: tổng tín chỉ GPA - đã tích lũy
    final catalog = context.read<CourseCatalog>();
    final totalGpaCredits = catalog.totalCreditsInGpa;
    final remaining = (totalGpaCredits - eval.totalGpaCredits).clamp(0, 9999);
    final targetResult = tp.requiredGpaFor(remaining > 0 ? remaining : 30);
    final isFeasible = targetResult['isFeasible'] as bool;
    final reqAvg = targetResult['requiredAverage'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── GPA badges ─────────────────────────────────────────────
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildStatBadge('GPA', eval.currentGpa.toStringAsFixed(2), AppTheme.primaryBlue),
            _buildStatBadge('Xếp loại TT', eval.actualRank, Colors.teal),
            _buildStatBadge(
              'Học lại',
              '${eval.retakeCount} môn',
              eval.retakeCount >= 2 ? Colors.red : Colors.green.shade700,
            ),
            _buildStatBadge(
              'Tín chỉ TC',
              '${eval.totalAccumulatedCredits}',
              AppTheme.slate700,
            ),
          ],
        ),

        // ── Penalty warning ─────────────────────────────────────────
        if (eval.penaltyWarning.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: eval.hasRankPenalty
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: eval.hasRankPenalty
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Text(
              eval.penaltyWarning,
              style: TextStyle(
                fontSize: 12.5,
                color: eval.hasRankPenalty
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // ── Mục tiêu GPA ────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mục tiêu: ${tp.targetGpa.toStringAsFixed(1)} (${_rankFor(tp.targetGpa)})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isFeasible
                        ? 'Cần đạt TB $reqAvg/10 ở các môn còn lại → Khả thi'
                        : 'Cần đạt TB $reqAvg/10 → Không khả thi! Nên điều chỉnh mục tiêu.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isFeasible
                          ? Colors.green.shade700
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showTargetGpaDialog(ctx, eval.currentGpa),
              icon: const Icon(Icons.tune, size: 15),
              label: const Text('Đổi mục tiêu', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ── Hướng dẫn dùng chat ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy_outlined, size: 15, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Hỏi Chat AI bên phải để nhận tư vấn chiến lược chi tiết dựa trên GPA thực tế của bạn.',
                  style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Quick actions ───────────────────────────────────────────
        Wrap(
          spacing: 8,
          children: [
            _buildActionChip(
              ctx,
              icon: Icons.route_outlined,
              label: 'Phân tích các kỳ tiếp theo',
              onTap: () => _openAdvisorChat(ctx, level: 'fullRoadmap'),
            ),
            _buildActionChip(
              ctx,
              icon: Icons.chat_outlined,
              label: 'Gửi ảnh trong chat',
              onTap: () => widget.onAdvisorPrompt?.call(
                'Hãy mở nút gửi ảnh trong khung chat để tôi gửi bảng điểm và yêu cầu phân tích các kỳ tiếp theo.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppTheme.slate700),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.slate700)),
          ],
        ),
      ),
    );
  }

  /// Mở khung chat và gợi ý câu hỏi tư vấn chiến lược
  void _openAdvisorChat(BuildContext ctx, {String level = 'fullRoadmap'}) {
    final tp = context.read<TranscriptProvider>();
    final prompt = tp.hasTranscript
        ? 'Hãy phân tích chiến lược học tập cho các học kỳ tiếp theo dựa trên bảng điểm đã xác nhận của tôi. '
          'Mục tiêu GPA tốt nghiệp là ${tp.targetGpa.toStringAsFixed(1)}. '
          'Chỉ rõ môn ưu tiên, lý do, tín chỉ và việc cần làm theo từng kỳ.'
        : 'Hãy phân tích chiến lược học tập cho các học kỳ tiếp theo dựa trên chương trình đào tạo. Tôi chưa có bảng điểm.';
    widget.onAdvisorPrompt?.call(prompt);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('Đã đưa yêu cầu phân tích vào Chat AI bên phải.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }
}
