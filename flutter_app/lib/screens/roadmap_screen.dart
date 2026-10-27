import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/graph/views/graph_view_screen.dart';
import '../models/course.dart';
import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../state/learning_profile_provider.dart';
import '../services/learning_progress.dart';
import '../theme/app_theme.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  bool _showGraph = false;
  int? _semester;
  bool _nextOnly = false;
  String _query = '';

  void _openCourse(String code) =>
      Navigator.pushNamed(context, '/courses/${Uri.encodeComponent(code)}');

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    final transcript = context.watch<TranscriptProvider>();
    final profile = context.watch<LearningProfileProvider>();
    final progress = LearningProgress(
      catalog.courses,
      transcript.entries,
      currentSemester: profile.currentSemester,
    );
    if (catalog.isLoading && catalog.courses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lộ trình học tập')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (catalog.error != null && catalog.courses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lộ trình học tập')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(catalog.error!),
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

    final semesters = catalog.courses.map((c) => c.semester).toSet().toList()
      ..sort();
    final visible =
        catalog.courses.where((c) {
          final matchSemester = _nextOnly
              ? c.semester == progress.nextSemester
              : _semester == null || c.semester == _semester;
          final q = _query.trim().toLowerCase();
          return matchSemester &&
              (q.isEmpty ||
                  c.code.toLowerCase().contains(q) ||
                  c.name.toLowerCase().contains(q) ||
                  c.nameVi.toLowerCase().contains(q));
        }).toList()..sort((a, b) {
          final bySemester = a.semester.compareTo(b.semester);
          return bySemester != 0 ? bySemester : a.code.compareTo(b.code);
        });

    return Scaffold(
      appBar: AppBar(title: const Text('Lộ trình học tập')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Theo học kỳ'),
                    selected: !_showGraph,
                    onSelected: (_) => setState(() => _showGraph = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Sơ đồ'),
                    selected: _showGraph,
                    onSelected: (_) => setState(() => _showGraph = true),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _showGraph
                ? GraphViewScreen(onOpenDetail: _openCourse)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Tìm mã hoặc tên môn học',
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      if (!transcript.hasTranscript)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Text(
                            'Chưa có bảng điểm: điều kiện học dưới đây chỉ là thông tin chương trình, chưa xác nhận bạn đủ điều kiện.',
                          ),
                        ),
                      SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          children: [
                            if (progress.nextSemester != null) ...[
                              ChoiceChip(
                                label: Text(
                                  'Kỳ tới · HK${progress.nextSemester}',
                                ),
                                selected: _nextOnly,
                                onSelected: (_) =>
                                    setState(() => _nextOnly = true),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ChoiceChip(
                              label: const Text('Tất cả'),
                              selected: !_nextOnly && _semester == null,
                              onSelected: (_) => setState(() {
                                _nextOnly = false;
                                _semester = null;
                              }),
                            ),
                            for (final semester in semesters) ...[
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text('HK $semester'),
                                selected: !_nextOnly && _semester == semester,
                                onSelected: (_) => setState(() {
                                  _nextOnly = false;
                                  _semester = semester;
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? Center(
                                child: Text(
                                  _nextOnly
                                      ? 'Không có môn ở kỳ kế tiếp trong chương trình hiện tại.'
                                      : 'Không tìm thấy môn học.',
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  24,
                                ),
                                itemCount: visible.length,
                                itemBuilder: (context, index) => _CourseTile(
                                  course: visible[index],
                                  progress: progress.status(visible[index]),
                                  hasTranscript: transcript.hasTranscript,
                                  onTap: () => _openCourse(visible[index].code),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.progress,
    required this.hasTranscript,
    required this.onTap,
  });
  final Course course;
  final CourseProgress progress;
  final bool hasTranscript;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final prerequisites = course.prerequisitesNorm.isNotEmpty
        ? course.prerequisitesNorm
        : course.prerequisites;
    final status = switch (progress.readiness) {
      CourseReadiness.completed =>
        'Đã hoàn thành · ${progress.score?.toStringAsFixed(1) ?? 'chưa có điểm'}',
      CourseReadiness.inProgress => 'Đang học',
      _ when !hasTranscript => 'Chưa xác nhận điều kiện: cần nhập bảng điểm',
      CourseReadiness.ready => 'Đủ tiên quyết theo dữ liệu đã nhập',
      CourseReadiness.blocked =>
        'Còn thiếu: ${progress.missingPrerequisites.join(', ')}',
      CourseReadiness.unverified =>
        'Cần xác minh mã tiên quyết: ${progress.unverifiedPrerequisites.join(', ')}',
    };
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          '${course.code} · ${course.nameVi.isNotEmpty ? course.nameVi : course.name}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Học kỳ ${course.semester} · ${course.credits} tín chỉ'),
            if (prerequisites.isNotEmpty)
              Text('Tiên quyết: ${prerequisites.join(', ')}'),
            Text(
              status,
              style: TextStyle(
                color: progress.readiness == CourseReadiness.completed
                    ? AppTheme.success
                    : AppTheme.slate600,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
