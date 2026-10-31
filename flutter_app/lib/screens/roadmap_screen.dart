import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/graph/views/graph_view_screen.dart';
import '../models/course.dart';
import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../state/learning_profile_provider.dart';
import '../services/learning_progress.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/course_visuals.dart';

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
    const title = 'Lộ trình học tập';
    if (catalog.isLoading && catalog.courses.isEmpty) {
      return const Scaffold(
        appBar: FlmAppBar(title: title),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (catalog.error != null && catalog.courses.isEmpty) {
      return Scaffold(
        appBar: const FlmAppBar(title: title),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppTheme.accentOrange,
              ),
              const SizedBox(height: 12),
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
    final totalCredits = catalog.courses.fold<int>(0, (s, c) => s + c.credits);
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

    // Flatten into semester headers followed by their courses.
    final items = <Object>[];
    int? lastSemester;
    for (final course in visible) {
      if (course.semester != lastSemester) {
        final inSemester = visible
            .where((c) => c.semester == course.semester)
            .toList();
        items.add(
          _SemesterGroup(
            semester: course.semester,
            courses: inSemester.length,
            credits: inSemester.fold(0, (s, c) => s + c.credits),
            completed: inSemester
                .where(
                  (c) =>
                      progress.status(c).readiness ==
                      CourseReadiness.completed,
                )
                .length,
            isNext: course.semester == progress.nextSemester,
          ),
        );
        lastSemester = course.semester;
      }
      items.add(course);
    }

    return Scaffold(
      appBar: FlmAppBar(
        title: title,
        subtitle:
            '${catalog.curriculum?.id ?? 'Chương trình đào tạo'} · ${catalog.courses.length} môn · $totalCredits tín chỉ',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.view_agenda_outlined, size: 18),
                  label: Text('Theo học kỳ'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.hub_outlined, size: 18),
                  label: Text('Sơ đồ'),
                ),
              ],
              selected: {_showGraph},
              onSelectionChanged: (value) =>
                  setState(() => _showGraph = value.first),
            ),
          ),
          Expanded(
            child: _showGraph
                ? GraphViewScreen(onOpenDetail: _openCourse)
                : CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (!_nextOnly && _semester == null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                            child: _ProgressHero(
                              progress: progress,
                              hasTranscript: transcript.hasTranscript,
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Tìm môn học',
                              prefixIcon: Icon(Icons.search_rounded),
                              hintText: 'Tìm mã hoặc tên môn học',
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                          child: Row(
                            children: [
                              if (progress.nextSemester != null) ...[
                                _SemesterChip(
                                  label: 'Kỳ tới · HK${progress.nextSemester}',
                                  icon: Icons.flag_rounded,
                                  palette: const SemesterPalette(
                                    AppTheme.accentOrange,
                                    AppTheme.peBadgeBg,
                                  ),
                                  selected: _nextOnly,
                                  onSelected: () =>
                                      setState(() => _nextOnly = true),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _SemesterChip(
                                label: 'Tất cả',
                                palette: const SemesterPalette(
                                  AppTheme.primaryDark,
                                  AppTheme.primaryLight,
                                ),
                                selected: !_nextOnly && _semester == null,
                                onSelected: () => setState(() {
                                  _nextOnly = false;
                                  _semester = null;
                                }),
                              ),
                              for (final semester in semesters) ...[
                                const SizedBox(width: 8),
                                _SemesterChip(
                                  label: 'HK $semester',
                                  palette: SemesterPalette.of(semester),
                                  dot: true,
                                  selected: !_nextOnly && _semester == semester,
                                  onSelected: () => setState(() {
                                    _nextOnly = false;
                                    _semester = semester;
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const IconTile(
                                    icon: Icons.search_off_rounded,
                                    color: AppTheme.slate600,
                                    size: 56,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _nextOnly
                                        ? 'Không có môn ở kỳ kế tiếp trong chương trình hiện tại.'
                                        : 'Không tìm thấy môn học.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          sliver: SliverList.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is _SemesterGroup) {
                                return _SemesterHeader(group: item);
                              }
                              final course = item as Course;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CourseTile(
                                  course: course,
                                  progress: progress.status(course),
                                  hasTranscript: transcript.hasTranscript,
                                  onTap: () => _openCourse(course.code),
                                ),
                              );
                            },
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

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.progress, required this.hasTranscript});
  final LearningProgress progress;
  final bool hasTranscript;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.completionRatio * 100).round();
    return HeroPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tiến độ chương trình',
                  style: TextStyle(
                    color: Color(0xFFE3F2FD),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasTranscript)
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasTranscript
                ? '${progress.completedCount}/${progress.totalCount} môn hoàn thành'
                : '${progress.totalCount} môn trong chương trình',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: hasTranscript ? progress.completionRatio : 0,
              minHeight: 8,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              semanticsLabel: 'Tiến độ theo bảng điểm đã nhập',
              semanticsValue: '$percent%',
            ),
          ),
          const SizedBox(height: 14),
          if (hasTranscript)
            Row(
              children: [
                Expanded(
                  child: HeroStat(
                    value: '${progress.ongoingCount}',
                    label: 'Đang học',
                  ),
                ),
                Expanded(
                  child: HeroStat(
                    value: '${progress.remainingCount}',
                    label: 'Còn lại',
                  ),
                ),
                Expanded(
                  child: HeroStat(
                    value: '${progress.failedCodes.length}',
                    label: 'Cần học lại',
                  ),
                ),
              ],
            )
          else
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chưa có bảng điểm: điều kiện học dưới đây chỉ là thông tin chương trình, chưa xác nhận bạn đủ điều kiện.',
                    style: TextStyle(
                      color: Color(0xFFE3F2FD),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SemesterChip extends StatelessWidget {
  const _SemesterChip({
    required this.label,
    required this.palette,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.dot = false,
  });
  final String label;
  final SemesterPalette palette;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    showCheckmark: false,
    avatar: icon != null
        ? Icon(icon, size: 16, color: selected ? Colors.white : palette.fg)
        : dot
        ? Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: selected ? Colors.white : palette.fg,
              shape: BoxShape.circle,
            ),
          )
        : null,
    label: Text(label),
    labelStyle: TextStyle(
      fontWeight: FontWeight.w700,
      color: selected ? Colors.white : palette.fg,
    ),
    selected: selected,
    selectedColor: palette.fg,
    backgroundColor: palette.bg,
    side: BorderSide(color: selected ? palette.fg : Colors.transparent),
    shape: const StadiumBorder(),
    onSelected: (_) => onSelected(),
  );
}

class _SemesterGroup {
  const _SemesterGroup({
    required this.semester,
    required this.courses,
    required this.credits,
    required this.completed,
    required this.isNext,
  });
  final int semester;
  final int courses;
  final int credits;
  final int completed;
  final bool isNext;
}

class _SemesterHeader extends StatelessWidget {
  const _SemesterHeader({required this.group});
  final _SemesterGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = SemesterPalette.of(group.semester);
    final ratio = group.courses == 0 ? 0.0 : group.completed / group.courses;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.fg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${group.semester}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Học kỳ ${group.semester}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${group.courses} môn · ${group.credits} TC · ${group.completed}/${group.courses}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 12.5),
                        ),
                      ),
                      if (group.isNext) ...[
                        const SizedBox(width: 6),
                        const StatusPill(
                          label: 'Kỳ tới',
                          icon: Icons.flag_rounded,
                          color: AppTheme.accentOrange,
                          background: AppTheme.peBadgeBg,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 4,
                      color: palette.fg,
                      backgroundColor: palette.bg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final palette = SemesterPalette.of(course.semester);
    final style = ReadinessStyle.of(progress.readiness, known: hasTranscript);
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
    final name = course.nameVi.isNotEmpty ? course.nameVi : course.name;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          ListTile(
                onTap: onTap,
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
                leading: IconTile(
                  icon: courseIcon(course.code),
                  color: palette.fg,
                  background: palette.bg,
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${course.code} · ${course.credits} tín chỉ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: palette.fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate900,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (prerequisites.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                size: 15,
                                color: AppTheme.slate600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Tiên quyết: ${prerequisites.join(', ')}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.slate600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusPill(
                            label: status,
                            icon: style.icon,
                            color: style.fg,
                            background: style.bg,
                          ),
                          if (course.hasPe)
                            const StatusPill(
                              label: 'Có PE',
                              icon: Icons.computer_rounded,
                              color: AppTheme.peBadgeText,
                              background: AppTheme.peBadgeBg,
                            ),
                          if (!course.countsInGpa)
                            const StatusPill(
                              label: 'Không tính GPA',
                              color: AppTheme.nonGpaBadgeText,
                              background: AppTheme.nonGpaBadgeBg,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.slate600,
                ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ExcludeSemantics(child: ColoredBox(color: palette.fg)),
          ),
        ],
      ),
    );
  }
}
