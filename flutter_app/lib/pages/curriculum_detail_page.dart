import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_panel.dart';
import '../features/graph/views/graph_view_screen.dart';
import '../models/course.dart';
import '../models/curriculum.dart';
import '../models/load_status.dart';
import '../widgets/data_state_view.dart';
import '../services/grade_calculator.dart';
import '../services/learning_progress.dart';
import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/breadcrumb_nav.dart';
import '../widgets/course_summary_modal.dart';
import '../widgets/grade_strategy_panel.dart';
import '../widgets/hover_card.dart';
import '../widgets/status_badge.dart';
import 'course_detail_page.dart';

class CurriculumDetailPage extends StatefulWidget {
  final String curriculumId;
  final int initialTabIndex;

  const CurriculumDetailPage({
    super.key,
    required this.curriculumId,
    this.initialTabIndex = 1,
  });

  @override
  State<CurriculumDetailPage> createState() => _CurriculumDetailPageState();
}

class _CurriculumDetailPageState extends State<CurriculumDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _semesterScrollController = ScrollController();

  String _searchQuery = '';
  String _courseStatusFilter = 'all';
  bool? _courseGpaFilter;
  int? _expandedSemester;
  bool _semesterSelectionInitialized = false;
  bool _showRightChat = true;
  String? _advisorPrompt;

  /// Môn đang chọn, đồng bộ hai chiều giữa tab "Danh sách môn" và tab Map.
  String? _selectedCourseCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _semesterScrollController.dispose();
    super.dispose();
  }

  void _openCourseDetail(String code) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CourseDetailPage(code: code, curriculumId: widget.curriculumId),
      ),
    );
  }

  /// Mở chat panel và gợi câu hỏi tư vấn chiến lược theo học kỳ hoặc môn.
  /// Dữ kiện GPA được tính bằng code (GradeCalculator) và gửi kèm trong student_context.
  void _showAdvisorDialog({String? semesterTitle, String? courseCode}) {
    final tp = context.read<TranscriptProvider>();
    // Build suggested question để người dùng có thể hỏi chat
    String suggestedQuestion;
    if (courseCode != null) {
      suggestedQuestion =
          'Tư vấn cách học và ôn thi môn $courseCode để đạt điểm cao.';
    } else if (semesterTitle != null) {
      suggestedQuestion =
          'Chiến lược học tập và phân bổ thời gian trong $semesterTitle. Tôi nên ưu tiên môn nào?';
    } else {
      final hasData = tp.hasTranscript;
      final eval = hasData ? tp.evaluation : null;
      suggestedQuestion = hasData
          ? 'GPA hiện tại của tôi là ${eval!.currentGpa}. Mục tiêu tốt nghiệp ${tp.targetGpa}. Tôi cần làm gì từ giờ đến cuối?'
          : 'Tư vấn lộ trình học tập toàn khóa dựa trên chương trình đào tạo. Tôi chưa import bảng điểm.';
    }

    _openAdvisor(prompt: suggestedQuestion);
  }

  void _openAdvisor({String? prompt}) {
    setState(() {
      _showRightChat = true;
      if (prompt != null) _advisorPrompt = prompt;
    });
    if (MediaQuery.sizeOf(context).width >= 960) return;
    final curriculum = context.read<CourseCatalog>().curriculum!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.85,
          child: ContextualChatPanel(
            scope: 'curriculum',
            scopeId: curriculum.id,
            title: 'Trợ lý Khung ${curriculum.id}',
            subtitle: curriculum.nameVi,
            semesterNumber: _expandedSemester,
            suggestedQuestions: _advisorPrompt == null
                ? null
                : [_advisorPrompt!],
            onClose: () => Navigator.pop(sheetContext),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    final curriculum = catalog.curriculum;

    if (curriculum == null || curriculum.id != widget.curriculumId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chương trình học')),
        body: DataStateView(
          status: catalog.isLoading ? LoadStatus.loading : LoadStatus.error,
          message: catalog.error ?? 'Chưa có dữ liệu cho chương trình này.',
          onRetry: catalog.isLoading ? null : catalog.load,
        ),
      );
    }
    final activeCurriculum = curriculum;

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: const Text('Chương trình học'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              onTap: (index) => setState(() {}),
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.slate600,
              indicatorColor: AppTheme.primaryBlue,
              indicatorWeight: 3,
              isScrollable: false,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Tổng quan'),
                Tab(text: 'Môn học'),
                Tab(text: 'Sơ đồ'),
              ],
            ),
          ),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeCurriculum.id,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    activeCurriculum.nameVi.isNotEmpty
                        ? activeCurriculum.nameVi
                        : activeCurriculum.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${activeCurriculum.totalSubjects} môn · ${activeCurriculum.totalCredits} tín chỉ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          // Breadcrumb Navigation
          if (MediaQuery.sizeOf(context).width >= 600)
            BreadcrumbNav(
              items: [
                BreadcrumbItem(
                  label: 'Chương trình khung',
                  onTap: () => Navigator.pop(context),
                ),
                BreadcrumbItem(
                  label: '${activeCurriculum.id} (${activeCurriculum.major})',
                ),
              ],
            ),

          // Main 2-column layout (Left: Tab Content, Right: Fixed Chat Panel)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 960;
                final showChatPanel = _showRightChat && isDesktop;

                return Row(
                  children: [
                    // Left Column: Tab Views
                    Expanded(
                      flex: showChatPanel ? 65 : 100,
                      child: IndexedStack(
                        index: _tabController.index,
                        children: [
                          // Tab 1: Tổng quan
                          _buildOverviewTab(context, catalog, activeCurriculum),

                          // Tab 2: Danh sách môn
                          _buildSubjectListTab(
                            context,
                            catalog,
                            activeCurriculum,
                          ),

                          // Tab 3: Map Graph View
                          GraphViewScreen(
                            selectedCode: _selectedCourseCode,
                            onNodeSelected: (code) =>
                                setState(() => _selectedCourseCode = code),
                            onOpenDetail: _openCourseDetail,
                            onAdvisorRequested: (code) =>
                                _showAdvisorDialog(courseCode: code),
                          ),
                        ],
                      ),
                    ),

                    // Right Column: Fixed Contextual Chat Panel
                    if (showChatPanel)
                      Expanded(
                        flex: 35,
                        child: ContextualChatPanel(
                          scope: 'curriculum',
                          scopeId: activeCurriculum.id,
                          title: 'Trợ lý Khung ${activeCurriculum.id}',
                          subtitle: activeCurriculum.nameVi,
                          semesterNumber: _expandedSemester,
                          suggestedQuestions: _advisorPrompt == null
                              ? null
                              : [_advisorPrompt!],
                          onClose: () => setState(() => _showRightChat = false),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          _showRightChat && MediaQuery.sizeOf(context).width >= 960
          ? null
          : FloatingActionButton(
              tooltip: 'Hỏi Trợ lý AI',
              onPressed: () => _openAdvisor(),
              child: const Icon(Icons.smart_toy_outlined),
            ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    CourseCatalog catalog,
    Curriculum curriculum,
  ) {
    final totalCredits = catalog.totalCredits;
    final totalCreditsGpa = catalog.totalCreditsInGpa;
    final subjectCount = catalog.courses.length;
    final semCount = curriculum.semesterCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        curriculum.nameVi.isNotEmpty
                            ? curriculum.nameVi
                            : curriculum.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${curriculum.id} - ${curriculum.major} - ${curriculum.institution}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.slate600,
                        ),
                      ),
                      const Divider(height: 28),
                      Wrap(
                        spacing: 24,
                        runSpacing: 14,
                        children: [
                          _buildPropItem(
                            'Quyết định đào tạo',
                            curriculum.decisionNo,
                          ),
                          _buildPropItem(
                            'Trình độ đào tạo',
                            curriculum.degreeLevel,
                          ),
                          _buildPropItem('Tổng số học kỳ', '$semCount học kỳ'),
                          _buildPropItem(
                            'Tổng số môn học',
                            '$subjectCount Môn',
                          ),
                          _buildPropItem(
                            'Tổng số tín chỉ',
                            '$totalCredits Tín chỉ',
                          ),
                          _buildPropItem(
                            'Tín chỉ tính GPA',
                            '$totalCreditsGpa Tín chỉ',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Bảng điểm & Chiến lược (Mục 7) ─────────────────────
              GradeStrategyPanel(
                curriculumId: widget.curriculumId,
                onAdvisorPrompt: (prompt) {
                  _openAdvisor(prompt: prompt);
                },
              ),

              const SizedBox(height: 24),

              // Program Learning Outcomes (PLOs)
              if (catalog.plos.isNotEmpty) ...[
                const Text(
                  'Chuẩn đầu ra chương trình đào tạo (PLOs)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slate900,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: catalog.plos.length,
                    separatorBuilder: (ctx, index) =>
                        const Divider(height: 1, color: AppTheme.slate200),
                    itemBuilder: (context, index) {
                      final plo = catalog.plos[index];
                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plo.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                plo.description,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropItem(String label, String value) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.slate600)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectListTab(
    BuildContext context,
    CourseCatalog catalog,
    Curriculum curriculum,
  ) {
    final Map<int, List<Course>> semesterMap = {};
    for (final course in catalog.courses) {
      semesterMap.putIfAbsent(course.semester, () => []).add(course);
    }
    final semesters = semesterMap.keys.toList()..sort();
    if (!_semesterSelectionInitialized && semesters.isNotEmpty) {
      _expandedSemester = semesters.first;
      _semesterSelectionInitialized = true;
    }
    final transcript = context.watch<TranscriptProvider>();

    final query = _searchQuery.toLowerCase();
    List<Course> filterList(List<Course> list) => list.where((c) {
      final matchesQuery =
          query.isEmpty ||
          c.code.toLowerCase().contains(query) ||
          c.name.toLowerCase().contains(query) ||
          c.nameVi.toLowerCase().contains(query);
      final status = _courseStatus(c, catalog, transcript);
      return matchesQuery &&
          (_courseStatusFilter == 'all' || status == _courseStatusFilter) &&
          (_courseGpaFilter == null || c.countsInGpa == _courseGpaFilter);
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm mã hoặc tên môn học',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.slate600,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Xóa nội dung tìm kiếm',
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (semesters.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < semesters.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text('HK${semesters[index]}'),
                            onPressed: () {
                              setState(
                                () => _expandedSemester = semesters[index],
                              );
                              if (_semesterScrollController.hasClients) {
                                final desktop =
                                    MediaQuery.of(context).size.width >= 760;
                                if (desktop) {
                                  _semesterScrollController.animateTo(
                                    (index * 316.0).clamp(
                                      0,
                                      _semesterScrollController
                                          .position
                                          .maxScrollExtent,
                                    ),
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOut,
                                  );
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              if (semesters.length > 1) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _courseStatusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Mọi trạng thái'),
                        ),
                        DropdownMenuItem(
                          value: 'passed',
                          child: Text('Đã đạt'),
                        ),
                        DropdownMenuItem(
                          value: 'failed',
                          child: Text('Chưa đạt'),
                        ),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('Đang học'),
                        ),
                        DropdownMenuItem(
                          value: 'not_started',
                          child: Text('Chưa học'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _courseStatusFilter = value ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<bool?>(
                      initialValue: _courseGpaFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Loại môn',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem<bool?>(
                          value: null,
                          child: Text('Mọi môn'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: true,
                          child: Text('Tính GPA'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: false,
                          child: Text('Không tính GPA'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _courseGpaFilter = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.slate200),
        Expanded(
          child: LayoutBuilder(
            builder: (context, limits) {
              final desktop = limits.maxWidth >= 760;
              return ListView.builder(
                controller: _semesterScrollController,
                scrollDirection: desktop ? Axis.horizontal : Axis.vertical,
                padding: EdgeInsets.fromLTRB(16, 16, 16, desktop ? 16 : 88),
                itemCount: semesters.length,
                itemBuilder: (context, index) {
                  final sem = semesters[index];
                  final allCourses = semesterMap[sem] ?? const <Course>[];
                  final courses = filterList(allCourses);
                  final credits = allCourses.fold<int>(
                    0,
                    (sum, course) => sum + course.credits,
                  );
                  final title = 'Học kỳ $sem';
                  final semesterEntries = transcript.entries
                      .where((entry) => entry.semester == sem)
                      .toList();
                  final semesterGpa = semesterEntries.isEmpty
                      ? null
                      : GradeCalculator.evaluateTranscript(semesterEntries)
                            .currentGpa;
                  final card = Card(
                    margin: EdgeInsets.only(
                      right: desktop ? 12 : 0,
                      bottom: desktop ? 0 : 12,
                    ),
                    child: ExpansionTile(
                      key: ValueKey(
                        'semester-$sem-${_expandedSemester == sem}',
                      ),
                      initiallyExpanded: desktop || _expandedSemester == sem,
                      onExpansionChanged: (expanded) => setState(() {
                        _expandedSemester = expanded ? sem : null;
                      }),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${allCourses.length} môn • $credits tín chỉ'
                        '${semesterGpa == null ? "" : " • GPA ${semesterGpa.toStringAsFixed(2)}"}',
                      ),
                      leading: IconButton(
                        tooltip: 'Tư vấn học kỳ',
                        icon: const Icon(
                          Icons.auto_awesome_outlined,
                          color: AppTheme.accentOrange,
                        ),
                        onPressed: () {
                          setState(() => _expandedSemester = sem);
                          _showAdvisorDialog(semesterTitle: title);
                        },
                      ),
                      children: [
                        if (courses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Không có môn phù hợp với nội dung tìm kiếm.',
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Column(
                              children: courses.map(_buildCourseCard).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                  return desktop ? SizedBox(width: 304, child: card) : card;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _courseStatus(
    Course course,
    CourseCatalog catalog,
    TranscriptProvider transcript,
  ) {
    final progress = LearningProgress(catalog.courses, transcript.entries);
    final status = progress.status(course).readiness;
    if (status == CourseReadiness.completed) return 'passed';
    if (status == CourseReadiness.inProgress) return 'in_progress';
    if (progress.failedCodes.contains(course.code.trim().toUpperCase())) {
      return 'failed';
    }
    return 'not_started';
  }

  Widget _buildCourseCard(Course course) {
    final isSelected = course.code == _selectedCourseCode;
    final status = switch (_courseStatus(
      course,
      context.read<CourseCatalog>(),
      context.read<TranscriptProvider>(),
    )) {
      'passed' => 'Đã đạt',
      'in_progress' => 'Đang học',
      'failed' => 'Chưa đạt / học lại',
      _ => 'Chưa học',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverCard(
        padding: const EdgeInsets.all(12),
        borderRadius: AppTheme.radiusMd,
        borderColor: isSelected ? AppTheme.primaryBlue : null,
        backgroundColor: isSelected ? AppTheme.primaryLight : null,
        onTap: () {
          setState(() => _selectedCourseCode = course.code);
          CourseSummaryModal.showFromCourse(
            context,
            course: course,
            onDetailsPressed: () => _openCourseDetail(course.code),
            onAdvisorPressed: () => _showAdvisorDialog(courseCode: course.code),
            onLinksPressed: () => setState(() => _tabController.index = 2),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    course.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                Text(
                  '${course.credits} TC',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              course.nameVi.isNotEmpty ? course.nameVi : course.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: AppTheme.slate900,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (course.nameVi.isNotEmpty && course.name != course.nameVi) ...[
              const SizedBox(height: 2),
              Text(
                course.name,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.slate600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                StatusBadge.pe(hasPe: course.hasPe),
                StatusBadge.gpa(countsInGpa: course.countsInGpa),
                if (context.read<TranscriptProvider>().hasTranscript)
                  Chip(
                    label: Text(status, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            if (course.prerequisites.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Tiên quyết: ${course.prerequisites.join(", ")}',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
