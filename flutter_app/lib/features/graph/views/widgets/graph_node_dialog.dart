import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../models/graph_models.dart';

enum GraphNodeAction { openDetail, showLinks, showPrerequisiteChain, advise }

/// Modal nhỏ khi click node (Mục 4.3.g). Click ra ngoài chỉ đóng modal, không đổi trang.
class GraphNodeDialog extends StatelessWidget {
  const GraphNodeDialog({
    super.key,
    required this.node,
    required this.prerequisites,
    required this.dependents,
    this.status,
  });

  final GraphNode node;
  final List<String> prerequisites;
  final List<String> dependents;
  final CourseProgressStatus? status;

  static Future<GraphNodeAction?> show(
    BuildContext context, {
    required GraphNode node,
    required List<String> prerequisites,
    required List<String> dependents,
    CourseProgressStatus? status,
  }) {
    return showDialog<GraphNodeAction>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => GraphNodeDialog(
        node: node,
        prerequisites: prerequisites,
        dependents: dependents,
        status: status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = semesterColor(node.semester);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 14, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: color, width: 1.4),
                    ),
                    child: Text(
                      node.id,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Đóng',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  node.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slate900),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(icon: Icons.school_outlined, label: '${node.credits} tín chỉ'),
                  _InfoChip(icon: Icons.calendar_month_outlined, label: node.semester == 0 ? 'Giai đoạn 0' : 'Học kỳ ${node.semester}'),
                  _InfoChip(
                    icon: node.countsInGpa ? Icons.functions : Icons.block,
                    label: node.countsInGpa ? 'Tính GPA' : 'Không tính GPA',
                  ),
                  if (status != null) _InfoChip(icon: Icons.flag_outlined, label: status!.label, color: status!.color),
                ],
              ),
              const SizedBox(height: 14),
              _LinkRow(label: 'Tiên quyết', codes: prerequisites, color: kPrerequisiteColor),
              const SizedBox(height: 6),
              _LinkRow(label: 'Mở khoá', codes: dependents, color: kDependentColor),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Xem chi tiết', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.pop(context, GraphNodeAction.openDetail),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.hub_outlined, size: 18),
                      label: const Text('Xem liên kết'),
                      onPressed: () => Navigator.pop(context, GraphNodeAction.showLinks),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.account_tree_outlined, size: 18),
                      label: const Text('Chuỗi tiên quyết'),
                      onPressed: prerequisites.isEmpty
                          ? null
                          : () => Navigator.pop(context, GraphNodeAction.showPrerequisiteChain),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentOrange,
                        side: const BorderSide(color: AppTheme.accentOrange),
                      ),
                      icon: const Icon(Icons.psychology_outlined, size: 18),
                      label: const Text('Tư vấn môn này'),
                      onPressed: () => Navigator.pop(context, GraphNodeAction.advise),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppTheme.slate700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.codes, required this.color});

  final String label;
  final List<String> codes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5, right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 13.5, color: AppTheme.slate600)),
        ),
        Expanded(
          child: Text(
            codes.isEmpty ? 'Không có' : codes.join(', '),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.slate800),
          ),
        ),
      ],
    );
  }
}
