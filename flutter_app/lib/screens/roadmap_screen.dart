import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_launcher.dart';
import '../features/graph/views/graph_view_screen.dart';
import '../models/course.dart';
import '../services/learning_progress.dart';
import '../state/course_catalog.dart';
import '../state/learning_profile_provider.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/course_visuals.dart';
import '../widgets/m3_components.dart';

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
  bool _dismissedNoTranscriptNotice = false;
  final ScrollController _chipScrollController = ScrollController();
  final Map<int, GlobalKey> _semesterKeys = {};
  final GlobalKey _allKey = GlobalKey();
  final GlobalKey _nextKey = GlobalKey();
  bool _hasInitialScrolled = false;

  GlobalKey _keyForSemester(int semester) =>
      _semesterKeys.putIfAbsent(semester, GlobalKey.new);

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx != null) {
        final disableAnim = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: disableAnim ? Duration.zero : const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

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
      return Scaffold(
        appBar: const FlmAppBar(title: title),
        body: _buildLoadingSkeleton(context),
      );
    }
    if (catalog.error != null && catalog.courses.isEmpty) {
      return Scaffold(
        appBar: const FlmAppBar(title: title),
        body: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Không thể tải lộ trình',
          description: catalog.error!,
          actionLabel: 'Thử lại',
          actionIcon: Icons.refresh_rounded,
          onAction: catalog.load,
        ),
      );
    }

    final semesters = catalog.courses.map((c) => c.semester).toSet().toList()..sort();
    final totalCredits = catalog.courses.fold<int>(0, (s, c) => s + c.credits);
    final visible = catalog.courses.where((c) {
      final matchSemester = _nextOnly
          ? c.semester == progress.nextSemester
          : _semester == null || c.semester == _semester;
      final q = _query.trim().toLowerCase();
      return matchSemester &&
          (q.isEmpty ||
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q) ||
              c.nameVi.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) {
        final bySemester = a.semester.compareTo(b.semester);
        return bySemester != 0 ? bySemester : a.code.compareTo(b.code);
      });

    // Group courses by semester for sticky headers.
    final semesterGroups = <int, List<Course>>{};
    for (final course in visible) {
      semesterGroups.putIfAbsent(course.semester, () => []).add(course);
    }

    return Scaffold(
      appBar: FlmAppBar(
        title: title,
        subtitle:
            '${catalog.curriculum?.id ?? 'Chương trình'} · ${catalog.courses.length} môn · $totalCredits tín chỉ',
        actions: [
          ContextualChatLauncher(
            curriculumId: catalog.curriculum?.id ?? '',
            contextKey: _showGraph
                ? 'graph'
                : _nextOnly
                    ? 'semester-${progress.nextSemester}'
                    : _semester == null ? 'roadmap' : 'semester-$_semester',
            title: _showGraph
                ? 'sơ đồ chương trình'
                : _nextOnly && progress.nextSemester != null
                    ? 'học kỳ ${progress.nextSemester}'
                    : _semester == null ? 'lộ trình học tập' : 'học kỳ $_semester',
            contextHint: _showGraph
                ? 'Sơ đồ quan hệ môn học trong chương trình ${catalog.curriculum?.id ?? ''}'
                : _nextOnly && progress.nextSemester != null
                    ? 'Học kỳ ${progress.nextSemester} trong chương trình ${catalog.curriculum?.id ?? ''}'
                    : _semester == null
                        ? 'Lộ trình học tập trong chương trình ${catalog.curriculum?.id ?? ''}'
                        : 'Học kỳ $_semester trong chương trình ${catalog.curriculum?.id ?? ''}',
            semesterNumber: _showGraph ? null : (_nextOnly ? progress.nextSemester : _semester),
            showLabel: true,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
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
              onSelectionChanged: (value) => setState(() => _showGraph = value.first),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: _showGraph
                  ? KeyedSubtree(
                      key: const ValueKey('roadmap_graph_view'),
                      child: GraphViewScreen(onOpenDetail: _openCourse),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('roadmap_list_view'),
                      child: CustomScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          if (!transcript.hasTranscript && !_dismissedNoTranscriptNotice)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: InlineBanner(
                                  message: 'Bạn chưa nhập bảng điểm. Hãy nhập để xem tiến độ và kiểm tra điều kiện tiên quyết.',
                                  severity: BannerSeverity.info,
                                  actionLabel: 'Nhập điểm',
                                  onAction: () => Navigator.pushNamed(context, '/transcript'),
                                  onDismiss: () => setState(() => _dismissedNoTranscriptNotice = true),
                                ),
                              ),
                            ),
                          if (!_nextOnly)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: _buildProgressHero(
                                  context: context,
                                  progress: progress,
                                  transcript: transcript,
                                  selectedSemester: _semester,
                                  totalCredits: totalCredits,
                                  totalCourses: catalog.courses.length,
                                  semestersCount: semesters.length,
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Tìm môn học',
                                  prefixIcon: Icon(Icons.search_rounded),
                                  hintText: 'Tìm theo mã hoặc tên môn...',
                                ),
                                onChanged: (value) => setState(() => _query = value),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final screenWidth = constraints.maxWidth;
                                final centerPadding = math.max(16.0, (screenWidth - 84) / 2);
                                final isAllSelected = !_nextOnly && _semester == null;
                                final hPadding = isAllSelected ? 16.0 : centerPadding;
                                if (!_hasInitialScrolled) {
                                  _hasInitialScrolled = true;
                                  if (_nextOnly) {
                                    _scrollToKey(_nextKey);
                                  } else if (_semester != null) {
                                    _scrollToKey(_keyForSemester(_semester!));
                                  }
                                }
                                return SingleChildScrollView(
                                  controller: _chipScrollController,
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.fromLTRB(hPadding, 6, hPadding, 6),
                                  child: Row(
                                    children: [
                                      if (progress.nextSemester != null) ...[
                                        _SemesterChip(
                                          key: _nextKey,
                                          label: 'Kỳ tới (HK${progress.nextSemester})',
                                          selected: _nextOnly,
                                          isNext: true,
                                          palette: SemesterPalette.of(progress.nextSemester!),
                                          onSelected: () {
                                            setState(() {
                                              _nextOnly = true;
                                              _semester = null;
                                            });
                                            _scrollToKey(_nextKey);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      _SemesterChip(
                                        key: _allKey,
                                        label: 'Tất cả (${catalog.courses.length})',
                                        selected: !_nextOnly && _semester == null,
                                        palette: const SemesterPalette(
                                          AppTheme.primaryBlue,
                                          Color(0xFFF1F5F9),
                                        ),
                                        onSelected: () {
                                          setState(() {
                                            _nextOnly = false;
                                            _semester = null;
                                          });
                                          _scrollToKey(_allKey);
                                        },
                                      ),
                                      for (final sem in semesters) ...[
                                        const SizedBox(width: 8),
                                        _SemesterChip(
                                          key: _keyForSemester(sem),
                                          label: 'HK$sem',
                                          selected: !_nextOnly && _semester == sem,
                                          palette: SemesterPalette.of(sem),
                                          isNext: sem == progress.nextSemester,
                                          onSelected: () {
                                            setState(() {
                                              _nextOnly = false;
                                              _semester = sem;
                                            });
                                            _scrollToKey(_keyForSemester(sem));
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          if (visible.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                child: EmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: 'Không tìm thấy môn học',
                                  description: _nextOnly
                                      ? 'Không có môn học ở kỳ kế tiếp trong chương trình.'
                                      : 'Không tìm thấy môn học nào khớp với từ khóa "$_query".',
                                ),
                              ),
                            )
                          else
                            for (final entry in semesterGroups.entries)
                              SliverMainAxisGroup(
                                slivers: [
                                  SliverPersistentHeader(
                                    pinned: true,
                                    delegate: _SemesterStickyHeaderDelegate(
                                      group: _SemesterGroup(
                                        semester: entry.key,
                                        courses: entry.value.length,
                                        credits: entry.value.fold(0, (s, c) => s + c.credits),
                                        completed: entry.value
                                            .where(
                                              (c) => progress.status(c).readiness == CourseReadiness.completed,
                                            )
                                            .length,
                                        isNext: entry.key == progress.nextSemester,
                                      ),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                    sliver: SliverList.builder(
                                      itemCount: entry.value.length,
                                      itemBuilder: (context, idx) {
                                        final course = entry.value[idx];
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
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHero({
    required BuildContext context,
    required LearningProgress progress,
    required TranscriptProvider transcript,
    required int? selectedSemester,
    required int totalCredits,
    required int totalCourses,
    required int semestersCount,
  }) {
    final customColors = context.customColors;
    final hasTranscript = transcript.hasTranscript;

    if (!hasTranscript) {
      return SummaryCard(
        title: 'Chương trình đào tạo',
        subtitle: 'Khung đào tạo chuẩn theo từng học kỳ',
        badge: StatusChip.neutral(label: 'Chưa có bảng điểm'),
        metrics: [
          SummaryMetric(
            label: 'Tổng số môn',
            value: '$totalCourses môn',
            icon: Icons.book_outlined,
          ),
          SummaryMetric(
            label: 'Tổng tín chỉ',
            value: '$totalCredits TC',
            icon: Icons.workspace_premium_outlined,
          ),
          SummaryMetric(
            label: 'Số học kỳ',
            value: '$semestersCount kỳ',
            icon: Icons.schedule_rounded,
          ),
        ],
      );
    }

    final percent = (progress.completionRatio * 100).round();
    final isSpecificSemester = selectedSemester != null;
    final headerTitle = isSpecificSemester
        ? 'Tiến độ · Học kỳ $selectedSemester'
        : 'Tiến độ toàn khóa';

    return SummaryCard(
      title: headerTitle,
      subtitle: '${progress.completedCount}/$totalCourses môn · ${transcript.evaluation.totalAccumulatedCredits}/$totalCredits tín chỉ',
      badge: StatusChip.success(label: '$percent% hoàn thành'),
      metrics: [
        SummaryMetric(
          label: 'Đã hoàn thành',
          value: '${progress.completedCount}/$totalCourses môn',
          icon: Icons.check_circle_outlined,
          color: customColors.success,
        ),
        SummaryMetric(
          label: 'Tín chỉ đạt',
          value: '${transcript.evaluation.totalAccumulatedCredits}/$totalCredits TC',
          icon: Icons.workspace_premium_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        SummaryMetric(
          label: 'Môn còn lại',
          value: '${totalCourses - progress.completedCount} môn',
          icon: Icons.pending_actions_rounded,
          color: AppTheme.accentOrange,
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonCard(height: 120),
        SizedBox(height: 14),
        SkeletonLine(width: double.infinity, height: 48),
        SizedBox(height: 14),
        Row(
          children: [
            SkeletonLine(width: 80, height: 32),
            SizedBox(width: 8),
            SkeletonLine(width: 80, height: 32),
            SizedBox(width: 8),
            SkeletonLine(width: 80, height: 32),
          ],
        ),
        SizedBox(height: 20),
        SkeletonCard(height: 90),
        SizedBox(height: 10),
        SkeletonCard(height: 90),
      ],
    );
  }
}

class _SemesterChip extends StatelessWidget {
  const _SemesterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onSelected,
    this.isNext = false,
  });

  final String label;
  final bool selected;
  final SemesterPalette palette;
  final VoidCallback onSelected;
  final bool isNext;

  @override
  Widget build(BuildContext context) => FilterChip(
    showCheckmark: false,
    avatar: isNext
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
      fontSize: 13,
      color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
    ),
    selected: selected,
    selectedColor: palette.fg,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    side: BorderSide(
      color: selected ? palette.fg : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
      width: selected ? 1.5 : 1.0,
    ),
    elevation: selected ? 1.0 : 0.0,
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

class _SemesterStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SemesterStickyHeaderDelegate({required this.group});

  final _SemesterGroup group;

  @override
  double get minExtent => 68.0;

  @override
  double get maxExtent => 68.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: overlapsContent ? 1.5 : 0.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: _SemesterHeader(group: group),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SemesterStickyHeaderDelegate oldDelegate) {
    return oldDelegate.group.semester != group.semester ||
        oldDelegate.group.completed != group.completed ||
        oldDelegate.group.courses != group.courses ||
        oldDelegate.group.isNext != group.isNext;
  }
}

class _SemesterHeader extends StatelessWidget {
  const _SemesterHeader({required this.group});
  final _SemesterGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = SemesterPalette.of(group.semester);
    final ratio = group.courses == 0 ? 0.0 : group.completed / group.courses;
    final curriculumId = context.read<CourseCatalog>().curriculum?.id ?? '';

    return Semantics(
      header: true,
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
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
                      ContextualChatLauncher(
                        curriculumId: curriculumId,
                        contextKey: 'semester-${group.semester}',
                        title: 'học kỳ ${group.semester}',
                        contextHint: 'Học kỳ ${group.semester} trong chương trình $curriculumId',
                        semesterNumber: group.semester,
                        suggestedQuestions: [
                          'Học kỳ này có những môn nào?',
                          'Tôi nên chuẩn bị gì cho học kỳ này?',
                        ],
                      ),
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
    final prerequisites = course.prerequisitesNorm.isNotEmpty
        ? course.prerequisitesNorm
        : course.prerequisites;
    final name = course.nameVi.isNotEmpty ? course.nameVi : course.name;

    // Resolve multimodal StatusChip ONLY when transcript is present
    Widget? statusChipWidget;
    if (hasTranscript) {
      statusChipWidget = switch (progress.readiness) {
        CourseReadiness.completed => StatusChip.passed(
            label: progress.score != null
                ? 'Đã đạt · ${progress.score!.toStringAsFixed(1)}'
                : 'Đã hoàn thành',
          ),
        CourseReadiness.inProgress => StatusChip.info(
            label: 'Đang học',
          ),
        CourseReadiness.ready => StatusChip.eligible(
            label: 'Có thể học',
          ),
        CourseReadiness.blocked => StatusChip.locked(
            label: progress.missingPrerequisites.length > 2
                ? 'Thiếu ${progress.missingPrerequisites.length} môn'
                : 'Thiếu: ${progress.missingPrerequisites.join(', ')}',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Môn còn thiếu cho ${course.code}: ${progress.missingPrerequisites.join(', ')}',
                  ),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        CourseReadiness.unverified => StatusChip.warning(
            label: progress.unverifiedPrerequisites.length > 2
                ? 'Ngoài CT: ${progress.unverifiedPrerequisites.length} môn'
                : 'Ngoài CT: ${progress.unverifiedPrerequisites.join(', ')}',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Tiên quyết ngoài CTĐT hiện tại: ${progress.unverifiedPrerequisites.join(', ')}',
                  ),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
      };
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
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
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
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
                          Icon(
                            Icons.link_rounded,
                            size: 15,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Tiên quyết: ${prerequisites.join(', ')}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      // Multimodal status chip: ONLY shown when transcript is present!
                      ?statusChipWidget,
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
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
