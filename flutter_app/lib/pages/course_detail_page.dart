import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/course_catalog.dart';

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    final course = catalog.findByCode(code);
    return Scaffold(
      appBar: AppBar(title: Text(course?.code ?? 'Chi tiết môn học')),
      body: course == null
          ? Center(
              child: Text(
                catalog.isLoading
                    ? 'Đang tải môn học...'
                    : 'Không tìm thấy môn học.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  course.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(course.code)),
                    Chip(label: Text('Học kỳ ${course.semester}')),
                    Chip(label: Text('${course.credits} tín chỉ')),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Mục tiêu học tập (LOs)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (course.learningOutcomes.isEmpty)
                  const Text('Chưa có thông tin mục tiêu học tập.')
                else
                  for (final outcome in course.learningOutcomes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $outcome'),
                    ),
                const SizedBox(height: 24),
                Text(
                  'Môn tiên quyết',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (course.prerequisites.isEmpty)
                  const Text('Không có môn tiên quyết.')
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final prerequisite in course.prerequisites)
                        ActionChip(
                          label: Text(prerequisite),
                          onPressed: catalog.findByCode(prerequisite) == null
                              ? null
                              : () => Navigator.pushNamed(
                                  context,
                                  '/courses/${Uri.encodeComponent(prerequisite)}',
                                ),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}
