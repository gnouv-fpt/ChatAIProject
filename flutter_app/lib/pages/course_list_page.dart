import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../state/course_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/course_visuals.dart';

class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  int? selectedSemester;
  final Map<int?, GlobalKey> _chipKeys = {};

  GlobalKey _keyForChip(int? semester) =>
      _chipKeys.putIfAbsent(semester, () => GlobalKey());

  void _selectSemester(int? semester) {
    setState(() => selectedSemester = semester);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _chipKeys[semester]?.currentContext;
      if (ctx == null) return;
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    if (catalog.isLoading && catalog.courses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (catalog.error != null && catalog.courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(catalog.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: catalog.load,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final semesters =
        catalog.courses.map((course) => course.semester).toSet().toList()
          ..sort();
    final visible =
        catalog.courses
            .where(
              (course) =>
                  selectedSemester == null ||
                  course.semester == selectedSemester,
            )
            .toList()
          ..sort((a, b) {
            final order = a.semester.compareTo(b.semester);
            return order != 0 ? order : a.code.compareTo(b.code);
          });

    final screenWidth = MediaQuery.sizeOf(context).width;
    final centerPadding = ((screenWidth - 96) / 2).clamp(16.0, 200.0);

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SectionHeader(
              title: 'Danh sách môn học theo học kỳ',
              icon: Icons.menu_book_outlined,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: centerPadding,
              vertical: 8,
            ),
            child: Row(
              children: [
                KeyedSubtree(
                  key: _keyForChip(null),
                  child: ChoiceChip(
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: const Text('Tất cả'),
                    selected: selectedSemester == null,
                    onSelected: (_) => _selectSemester(null),
                  ),
                ),
                for (final semester in semesters) ...[
                  const SizedBox(width: 8),
                  KeyedSubtree(
                    key: _keyForChip(semester),
                    child: ChoiceChip(
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      label: Text('Học kỳ $semester'),
                      selected: selectedSemester == semester,
                      onSelected: (_) => _selectSemester(semester),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('Chưa có môn học nào.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) =>
                  _CourseCard(course: visible[index]),
            ),
          ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final palette = SemesterPalette.of(course.semester);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => Navigator.pushNamed(
          context,
          '/courses/${Uri.encodeComponent(course.code)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconTile(
                icon: courseIcon(course.code),
                color: palette.fg,
                background: palette.bg,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.code,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: palette.fg,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      course.nameVi.isNotEmpty ? course.nameVi : course.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Học kỳ ${course.semester}  •  ${course.credits} tín chỉ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.slate600),
            ],
          ),
        ),
      ),
    );
  }
}
