import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_panel.dart';
import '../features/graph/views/graph_view_screen.dart';
import '../models/course.dart';
import '../models/curriculum.dart';
import '../models/load_status.dart';
import '../services/grade_calculator.dart';
import '../services/learning_progress.dart';
import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/breadcrumb_nav.dart';
import '../widgets/course_summary_modal.dart';
import '../widgets/course_visuals.dart';
import '../widgets/data_state_view.dart';
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
  final ScrollController _chipScrollController = ScrollController();
  final Map<int, GlobalKey> _chipKeys = {};
  final Map<int, GlobalKey> _semesterCardKeys = {};

  String _searchQuery = '';
  String _courseStatusFilter = 'all';
  bool? _courseGpaFilter;
  int? _expandedSemester;
  bool _semesterSelectionInitialized = false;
  bool _showRightChat = true;
  String? _advisorPrompt;
  String? _advisorCourseCode;
  int? _advisorSemester;

  /// Môn đang chọn, đồng bộ hai chiều giữa tab "Danh sách môn" và tab Map.
  String? _selectedCourseCode;

  GlobalKey _keyForSemesterChip(int semester) =>
      _chipKeys.putIfAbsent(semester, () => GlobalKey());

  GlobalKey _keyForSemesterCard(int semester) =>
      _semesterCardKeys.putIfAbsent(semester, () => GlobalKey());

  void _scrollToSelectedChip(int semester) {
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

  void _scrollToSemesterCard(int semester, {int? index}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _semesterCardKeys[semester]?.currentContext;
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.0,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else if (index != null && _semesterScrollController.hasClients) {
        final approxOffset = (index * 76.0).clamp(
          0.0,
          _semesterScrollController.position.maxScrollExtent,
        );
        _semesterScrollController.animateTo(
          approxOffset,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

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
    _chipScrollController.dispose();
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

    _openAdvisor(
      prompt: suggestedQuestion,
      courseCode: courseCode,
      semester: semesterTitle == null ? null : _expandedSemester,
    );
  }

  void _openAdvisor({String? prompt, String? courseCode, int? semester}) {
    setState(() {
      _showRightChat = true;
      _advisorCourseCode = courseCode;
      _advisorSemester = semester;
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
          child: _buildAdvisorPanel(
            curriculum,
            onClose: () => Navigator.pop(sheetContext),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvisorPanel(Curriculum curriculum, {VoidCallback? onClose}) {
    final code = _advisorCourseCode;
    final semester = _advisorSemester;
    return ContextualChatPanel(
      scope: code == null ? 'curriculum' : 'subject',
      scopeId: code ??
          (semester == null
              ? curriculum.id
              : '${curriculum.id}:semester-$semester'),
      backendScopeId: code == null && semester != null ? curriculum.id : null,
      contextHint: code != null
          ? 'Môn $code trong chương trình ${curriculum.id}'
          : semester != null
          ? 'Học kỳ $semester trong chương trình ${curriculum.id}'
          : null,
      title: code != null
          ? 'Trợ lý môn $code'
          : semester != null
          ? 'Trợ lý học kỳ $semester'
          : 'Trợ lý Khung ${curriculum.id}',
      subtitle: curriculum.nameVi,
      semesterNumber: semester,
      suggestedQuestions: _advisorPrompt == null ? null : [_advisorPrompt!],
      onClose: onClose,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.slate200)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const IconTile(
                  icon: Icons.school_rounded,
                  color: AppTheme.primaryBlue,
                  background: AppTheme.primaryLight,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            activeCurriculum.id,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            '${activeCurriculum.totalSubjects} môn · ${activeCurriculum.totalCredits} tín chỉ',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeCurriculum.nameVi.isNotEmpty
                            ? activeCurriculum.nameVi
                            : activeCurriculum.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                        child: _buildAdvisorPanel(
                          activeCurriculum,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
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
                      const SizedBox(height: 8),
                      Text(
                        '${curriculum.id} · ${curriculum.major}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        curriculum.institution,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slate600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Detail Box: Trình độ & Quyết định đào tạo
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.slate50,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.slate200),
                        ),
                        child: Column(
                          children: [
                            _buildOverviewDetailRow(
                              icon: Icons.school_outlined,
                              label: 'Trình độ đào tạo',
                              value: curriculum.degreeLevel.isNotEmpty
                                  ? curriculum.degreeLevel
                                  : 'Đại học chính quy',
                            ),
                            const Divider(height: 16, color: AppTheme.slate200),
                            _buildOverviewDetailRow(
                              icon: Icons.gavel_outlined,
                              label: 'Quyết định đào tạo',
                              value: curriculum.decisionNo.isNotEmpty
                                  ? curriculum.decisionNo
                                  : 'Chưa có thông tin',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 2x2 Balanced Metrics Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.calendar_today_rounded,
                              label: 'Tổng số học kỳ',
                              value: '$semCount học kỳ',
                              iconColor: AppTheme.primaryBlue,
                              iconBg: AppTheme.primaryLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.menu_book_rounded,
                              label: 'Tổng số môn học',
                              value: '$subjectCount Môn',
                              iconColor: const Color(0xFF0D9488),
                              iconBg: const Color(0xFFCCFBF1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.workspace_premium_rounded,
                              label: 'Tổng số tín chỉ',
                              value: '$totalCredits Tín chỉ',
                              iconColor: const Color(0xFFD97706),
                              iconBg: const Color(0xFFFEF3C7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.insights_rounded,
                              label: 'Tín chỉ tính GPA',
                              value: '$totalCreditsGpa Tín chỉ',
                              iconColor: const Color(0xFF7C3AED),
                              iconBg: const Color(0xFFEDE9FE),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Bảng điểm & Chiến lược (Mục 7) ─────────────────────
              GradeStrategyPanel(
                curriculumId: widget.curriculumId,
                onAdvisorPrompt: (prompt) {
                  _openAdvisor(prompt: prompt);
                },
              ),

              const SizedBox(height: 20),

              // Program Learning Outcomes (PLOs)
              if (catalog.plos.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Chuẩn đầu ra chương trình đào tạo (PLOs)',
                  icon: Icons.verified_outlined,
                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plo.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryBlue,
                                  fontSize: 12.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              plo.description,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.55,
                                color: AppTheme.slate800,
                                letterSpacing: 0.15,
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

  Widget _buildOverviewDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slate600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      _expandedSemester = semesters.length == 1 ? semesters.first : null;
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
                          labelText: 'Tìm môn học',
                          hintText: 'Tìm mã hoặc tên môn học',
                          prefixIcon: const Icon(Icons.search, size: 20),
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
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.sizeOf(context).width;
                    final centerPadding = ((screenWidth - 80) / 2).clamp(
                      16.0,
                      180.0,
                    );
                    final hasSelection = _expandedSemester != null;
                    return SingleChildScrollView(
                      controller: _chipScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: hasSelection ? centerPadding : 16.0,
                      ),
                      child: Row(
                        children: [
                          for (var index = 0; index < semesters.length; index++)
                            Builder(
                              builder: (context) {
                                final sem = semesters[index];
                                final isSelected = _expandedSemester == sem;
                                final palette = SemesterPalette.of(sem);
                                return Padding(
                                  key: _keyForSemesterChip(sem),
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.padded,
                                    backgroundColor: isSelected
                                        ? palette.fg
                                        : palette.bg,
                                    side: BorderSide.none,
                                    shape: const StadiumBorder(),
                                    label: Text(
                                      'HK$sem',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : palette.fg,
                                      ),
                                    ),
                                    onPressed: () {
                                      final isDeselecting =
                                          _expandedSemester == sem;
                                      setState(() {
                                        _expandedSemester =
                                            isDeselecting ? null : sem;
                                      });
                                      if (!isDeselecting) {
                                        _scrollToSelectedChip(sem);
                                        _scrollToSemesterCard(sem, index: index);
                                      } else {
                                        if (_chipScrollController.hasClients) {
                                          _chipScrollController.animateTo(
                                            0,
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
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
                      : GradeCalculator.evaluateTranscript(
                          semesterEntries,
                        ).currentGpa;
                  final card = Card(
                    key: _keyForSemesterCard(sem),
                    margin: EdgeInsets.only(
                      right: desktop ? 12 : 0,
                      bottom: desktop ? 0 : 12,
                    ),
                    child: ExpansionTile(
                      key: ValueKey(
                        'semester-$sem-${_expandedSemester == sem}',
                      ),
                      initiallyExpanded: desktop || _expandedSemester == sem,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _expandedSemester = expanded ? sem : null;
                        });
                        if (expanded) {
                          _scrollToSelectedChip(sem);
                          _scrollToSemesterCard(sem, index: index);
                        }
                      },
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
    final palette = SemesterPalette.of(course.semester);
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
      child: SizedBox(
        width: double.infinity,
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
              onAdvisorPressed: () =>
                  _showAdvisorDialog(courseCode: course.code),
              onLinksPressed: () => setState(() => _tabController.index = 2),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      course.code,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: palette.fg,
                      ),
                    ),
                  ),
                  Text(
                    '${course.credits} TC',
                    style: const TextStyle(
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
                  fontSize: 14,
                  color: AppTheme.slate900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (course.nameVi.isNotEmpty && course.name != course.nameVi) ...[
                const SizedBox(height: 2),
                Text(
                  course.name,
                  style: const TextStyle(
                    fontSize: 12,
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
                      visualDensity: VisualDensity.compact,
                      label: Text(status, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
              if (course.prerequisites.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Tiên quyết: ${course.prerequisites.join(", ")}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
