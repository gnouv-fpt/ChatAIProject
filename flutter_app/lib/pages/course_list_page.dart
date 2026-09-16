import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../state/course_catalog.dart';

class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  int? selectedSemester;

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

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Danh sách môn học theo học kỳ'),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: selectedSemester == null,
                  onSelected: (_) => setState(() => selectedSemester = null),
                ),
                for (final semester in semesters) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Học kỳ $semester'),
                    selected: selectedSemester == semester,
                    onSelected: (_) =>
                        setState(() => selectedSemester = semester),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          '/courses/${Uri.encodeComponent(course.code)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.code, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 5),
              Text(course.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Học kỳ ${course.semester}  •  ${course.credits} tín chỉ'),
            ],
          ),
        ),
      ),
    );
  }
}
