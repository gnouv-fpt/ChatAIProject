import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../models/graph_models.dart';
import '../graph_painter.dart';

/// Bảng điều khiển thu gọn được kiểu Obsidian (Mục 4.3.f):
/// tìm kiếm, bộ lọc, hiển thị và lực mô phỏng.
class GraphControlPanel extends StatelessWidget {
  const GraphControlPanel({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.searchMatchCount,
    required this.semesters,
    required this.filters,
    required this.onFiltersChanged,
    required this.hasStatuses,
    required this.display,
    required this.onDisplayChanged,
    required this.showSemesterNodes,
    required this.onShowSemesterNodesChanged,
    required this.forces,
    required this.onForcesChanged,
    required this.onClose,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final int searchMatchCount;
  final List<int> semesters;
  final GraphFilters filters;
  final ValueChanged<GraphFilters> onFiltersChanged;
  final bool hasStatuses;
  final GraphDisplaySettings display;
  final ValueChanged<GraphDisplaySettings> onDisplayChanged;
  final bool showSemesterNodes;
  final ValueChanged<bool> onShowSemesterNodesChanged;
  final ForceSettings forces;
  final ValueChanged<ForceSettings> onForcesChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 20, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Bảng điều khiển',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slate900),
                    ),
                  ),
                  IconButton(tooltip: 'Thu gọn', icon: const Icon(Icons.chevron_right), onPressed: onClose),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(
                controller: searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tìm mã hoặc tên môn...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                        ),
                  helperText: searchController.text.isEmpty
                      ? null
                      : (searchMatchCount == 0 ? 'Không tìm thấy môn phù hợp' : 'Khớp $searchMatchCount môn • Enter để căn giữa'),
                ),
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _Section(
                      title: 'Bộ lọc',
                      icon: Icons.filter_alt_outlined,
                      initiallyExpanded: true,
                      trailing: filters.isDefault
                          ? null
                          : TextButton(
                              onPressed: () => onFiltersChanged(const GraphFilters()),
                              child: const Text('Xoá lọc'),
                            ),
                      children: _buildFilters(),
                    ),
                    _Section(
                      title: 'Hiển thị',
                      icon: Icons.visibility_outlined,
                      children: _buildDisplay(),
                    ),
                    _Section(
                      title: 'Lực mô phỏng (nâng cao)',
                      icon: Icons.bubble_chart_outlined,
                      children: _buildForces(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFilters() {
    return [
      const _Label('Học kỳ'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final sem in semesters)
            FilterChip(
              label: Text(semesterLabel(sem)),
              avatar: CircleAvatar(backgroundColor: semesterColor(sem), radius: 6),
              selected: filters.semesters.contains(sem),
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                final next = {...filters.semesters};
                selected ? next.add(sem) : next.remove(sem);
                onFiltersChanged(filters.copyWith(semesters: next));
              },
            ),
        ],
      ),
      const SizedBox(height: 10),
      const _Label('Trạng thái'),
      if (!hasStatuses)
        const Text(
          'Cần import bảng điểm để lọc theo trạng thái.',
          style: TextStyle(fontSize: 13, color: AppTheme.slate600, fontStyle: FontStyle.italic),
        )
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final status in CourseProgressStatus.values)
              FilterChip(
                label: Text(status.label),
                avatar: CircleAvatar(backgroundColor: status.color, radius: 6),
                selected: filters.statuses.contains(status),
                visualDensity: VisualDensity.compact,
                onSelected: (selected) {
                  final next = {...filters.statuses};
                  selected ? next.add(status) : next.remove(status);
                  onFiltersChanged(filters.copyWith(statuses: next));
                },
              ),
          ],
        ),
      const SizedBox(height: 10),
      const _Label('Tính GPA'),
      _TriSegment(
        value: filters.gpa,
        yesLabel: 'Tính GPA',
        noLabel: 'Không tính',
        onChanged: (v) => onFiltersChanged(filters.copyWith(gpa: v)),
      ),
      const SizedBox(height: 10),
      const _Label('Môn tiên quyết'),
      _TriSegment(
        value: filters.prerequisite,
        yesLabel: 'Có',
        noLabel: 'Không có',
        onChanged: (v) => onFiltersChanged(filters.copyWith(prerequisite: v)),
      ),
      _SwitchRow(
        label: 'Hiện node cô lập',
        value: filters.showIsolated,
        onChanged: (v) => onFiltersChanged(filters.copyWith(showIsolated: v)),
      ),
    ];
  }

  List<Widget> _buildDisplay() {
    return [
      _SwitchRow(
        label: 'Nhãn môn học',
        value: display.showLabels,
        onChanged: (v) => onDisplayChanged(display.copyWith(showLabels: v)),
      ),
      _SwitchRow(
        label: 'Mũi tên hướng',
        value: display.showArrows,
        onChanged: (v) => onDisplayChanged(display.copyWith(showArrows: v)),
      ),
      _SwitchRow(
        label: 'Hiện node học kỳ',
        value: showSemesterNodes,
        onChanged: onShowSemesterNodesChanged,
      ),
      _SwitchRow(
        label: 'Tô màu theo trạng thái',
        value: display.colorByStatus && hasStatuses,
        onChanged: hasStatuses ? (v) => onDisplayChanged(display.copyWith(colorByStatus: v)) : null,
      ),
      _SliderRow(
        label: 'Độ dày cạnh',
        value: display.edgeWidth,
        min: 0.6,
        max: 4,
        onChanged: (v) => onDisplayChanged(display.copyWith(edgeWidth: v)),
      ),
      _SliderRow(
        label: 'Kích thước node',
        value: display.nodeScale,
        min: 0.6,
        max: 1.8,
        onChanged: (v) => onDisplayChanged(display.copyWith(nodeScale: v)),
      ),
    ];
  }

  List<Widget> _buildForces() {
    return [
      _SliderRow(
        label: 'Lực đẩy',
        value: forces.repulsion,
        min: 300,
        max: 4000,
        onChanged: (v) => onForcesChanged(forces.copyWith(repulsion: v)),
      ),
      _SliderRow(
        label: 'Độ dài liên kết',
        value: forces.linkDistance,
        min: 40,
        max: 260,
        onChanged: (v) => onForcesChanged(forces.copyWith(linkDistance: v)),
      ),
      _SliderRow(
        label: 'Lực hút về tâm',
        value: forces.centerGravity,
        min: 0,
        max: 0.12,
        onChanged: (v) => onForcesChanged(forces.copyWith(centerGravity: v)),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => onForcesChanged(const ForceSettings()),
          child: const Text('Mặc định'),
        ),
      ),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, size: 20, color: AppTheme.slate700),
        title: Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            ?trailing,
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slate600)),
    );
  }
}

class _TriSegment extends StatelessWidget {
  const _TriSegment({required this.value, required this.yesLabel, required this.noLabel, required this.onChanged});

  final TriFilter value;
  final String yesLabel;
  final String noLabel;
  final ValueChanged<TriFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TriFilter>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          const ButtonSegment(value: TriFilter.all, label: Text('Tất cả')),
          ButtonSegment(value: TriFilter.yes, label: Text(yesLabel)),
          ButtonSegment(value: TriFilter.no, label: Text(noLabel)),
        ],
        selected: {value},
        onSelectionChanged: (set) => onChanged(set.first),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13.5, color: onChanged == null ? AppTheme.slate600 : AppTheme.slate800),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, color: AppTheme.slate800)),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
