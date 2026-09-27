import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_panel.dart';
import '../features/graph/views/graph_view_screen.dart';
import '../models/course.dart';
import '../models/curriculum.dart';
import '../state/course_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/breadcrumb_nav.dart';
import '../widgets/course_summary_modal.dart';
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
  final ScrollController _boardScrollController = ScrollController();

  String _searchQuery = '';
  int? _selectedSemesterFilter;
  bool _filterOnlyPe = false;
  bool _filterOnlyGpa = false;
  bool _isBoardView = true;
  bool _showRightChat = true;

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
    _boardScrollController.dispose();
    super.dispose();
  }

  void _scrollToSemester(int semester) {
    setState(() => _selectedSemesterFilter = semester);
    if (_isBoardView && _boardScrollController.hasClients) {
      final index = semester;
      final offset = (index * 320.0).clamp(0.0, _boardScrollController.position.maxScrollExtent);
      _boardScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openCourseDetail(String code) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseDetailPage(
          code: code,
          curriculumId: widget.curriculumId,
        ),
      ),
    );
  }

  void _showAdvisorDialog({String? semesterTitle, String? courseCode}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          courseCode != null
              ? 'Tư vấn môn học $courseCode'
              : (semesterTitle != null ? 'Chiến lược $semesterTitle' : 'Tư vấn lộ trình toàn khóa'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courseCode != null
                  ? 'Gợi ý phương pháp ôn tập, vượt qua bài thi thực hành PE và tối ưu điểm số môn $courseCode.'
                  : (semesterTitle != null
                      ? 'Phân bổ tải học tập và mức độ ưu tiên giữa các môn trong $semesterTitle.'
                      : 'Đánh giá điều kiện tốt nghiệp, số môn học lại tối đa trước khi bị hạ bậc, và tính toán điểm trung bình cần đạt.'),
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Text(
                'Bạn có thể gửi câu hỏi trực tiếp cho Trợ lý AI ở khung Chat bên phải để nhận giải pháp học tập chi tiết.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.slate700),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hỏi AI ngay'),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _showRightChat = true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    final curriculum = catalog.curriculum;

    if (curriculum == null && catalog.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activeCurriculum = curriculum ??
        Curriculum(
          id: widget.curriculumId,
          code: widget.curriculumId,
          name: 'Software Engineering',
          nameVi: 'Kỹ thuật phần mềm',
          totalCredits: 145,
          totalSubjects: 48,
          decisionNo: '1140/QĐ-ĐHFPT',
          degreeLevel: 'Bachelor',
          institution: 'FPT University',
          major: 'Software Engineering',
          subjects: const [],
        );

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${activeCurriculum.id} • ${activeCurriculum.nameVi.isNotEmpty ? activeCurriculum.nameVi : activeCurriculum.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              'Chương trình cử nhân CNTT • ${activeCurriculum.totalSubjects} môn • ${activeCurriculum.totalCredits} tín chỉ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.slate600),
            ),
          ],
        ),
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
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Tổng quan'),
                Tab(text: 'Danh sách môn'),
                Tab(text: 'Map (Graph Obsidian)'),
              ],
            ),
          ),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Breadcrumb Navigation
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
                          _buildSubjectListTab(context, catalog, activeCurriculum),

                          // Tab 3: Map Graph View
                          const GraphViewScreen(),
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
      floatingActionButton: _showRightChat
          ? null
          : Tooltip(
              message: 'Hỏi Trợ lý AI (FLM Chatbot)',
              child: InkWell(
                onTap: () {
                  if (MediaQuery.of(context).size.width < 960) {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SizedBox(
                        height: MediaQuery.of(context).size.height * 0.85,
                        child: ContextualChatPanel(
                          scope: 'curriculum',
                          scopeId: activeCurriculum.id,
                          title: 'Trợ lý Khung ${activeCurriculum.id}',
                          subtitle: activeCurriculum.nameVi,
                        ),
                      ),
                    );
                  } else {
                    setState(() => _showRightChat = true);
                  }
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.42),
                        blurRadius: 14,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, CourseCatalog catalog, Curriculum curriculum) {
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
                        curriculum.nameVi.isNotEmpty ? curriculum.nameVi : curriculum.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.slate900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${curriculum.id} - ${curriculum.major} - ${curriculum.institution}',
                        style: TextStyle(fontSize: 13, color: AppTheme.slate600),
                      ),
                      const Divider(height: 28),
                      Wrap(
                        spacing: 24,
                        runSpacing: 14,
                        children: [
                          _buildPropItem('Quyết định đào tạo', curriculum.decisionNo),
                          _buildPropItem('Trình độ đào tạo', curriculum.degreeLevel),
                          _buildPropItem('Tổng số học kỳ', '$semCount Học kỳ (Giai đoạn 0 - 9)'),
                          _buildPropItem('Tổng số môn học', '$subjectCount Môn'),
                          _buildPropItem('Tổng số tín chỉ', '$totalCredits Tín chỉ'),
                          _buildPropItem('Tín chỉ tính GPA', '$totalCreditsGpa Tín chỉ'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Grade Strategy & Advisor Area
              HoverCard(
                backgroundColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
                hoverBorderColor: AppTheme.accentAmber,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bảng điểm & Tư vấn Chiến lược Học tập (GPA)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Import bảng điểm để tính toán GPA thực tế, cảnh báo nguy cơ hạ bậc tốt nghiệp và nhận tư vấn chiến lược.',
                            style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Tư vấn chiến lược'),
                      onPressed: () => _showAdvisorDialog(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Program Learning Outcomes (PLOs)
              if (catalog.plos.isNotEmpty) ...[
                const Text(
                  'Chuẩn đầu ra chương trình đào tạo (PLOs)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.slate900),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: catalog.plos.length,
                    separatorBuilder: (ctx, index) => const Divider(height: 1, color: AppTheme.slate200),
                    itemBuilder: (context, index) {
                      final plo = catalog.plos[index];
                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                plo.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                plo.description,
                                style: const TextStyle(fontSize: 13.5, height: 1.35),
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
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
        ],
      ),
    );
  }

  Widget _buildSubjectListTab(BuildContext context, CourseCatalog catalog, Curriculum curriculum) {
    final Map<int, List<Course>> semesterMap = {};
    for (int s = 0; s <= 9; s++) {
      semesterMap[s] = [];
    }
    for (final course in catalog.courses) {
      semesterMap.putIfAbsent(course.semester, () => []).add(course);
    }

    List<Course> filterList(List<Course> list) {
      return list.where((c) {
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          final matchCode = c.code.toLowerCase().contains(q);
          final matchName = c.name.toLowerCase().contains(q);
          final matchNameVi = c.nameVi.toLowerCase().contains(q);
          if (!matchCode && !matchName && !matchNameVi) return false;
        }
        if (_filterOnlyPe && !c.hasPe) return false;
        if (_filterOnlyGpa && !c.countsInGpa) return false;
        return true;
      }).toList();
    }

    final semesters = semesterMap.keys.toList()..sort();

    return Column(
      children: [
        // Top Toolbar: Search Bar + Filter Chips + View Mode Switcher
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm theo mã môn (PRM393, SWD392) hoặc tên môn...',
                          hintStyle: TextStyle(fontSize: 13, color: AppTheme.slate600.withValues(alpha: 0.7)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilterChip(
                    label: const Text('Có thi PE'),
                    selected: _filterOnlyPe,
                    onSelected: (val) => setState(() => _filterOnlyPe = val),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Tính GPA'),
                    selected: _filterOnlyGpa,
                    onSelected: (val) => setState(() => _filterOnlyGpa = val),
                  ),
                  const SizedBox(width: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Board')),
                      ButtonSegment(value: false, label: Text('List')),
                    ],
                    selected: {_isBoardView},
                    onSelectionChanged: (set) => setState(() => _isBoardView = set.first),
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả kỳ'),
                      selected: _selectedSemesterFilter == null,
                      onSelected: (_) => setState(() => _selectedSemesterFilter = null),
                    ),
                    for (final sem in semesters) ...[
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(sem == 0 ? 'Giai đoạn 0' : 'Học kỳ $sem'),
                        selected: _selectedSemesterFilter == sem,
                        onSelected: (_) => _scrollToSemester(sem),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.slate200),
        Expanded(
          child: _isBoardView
              ? _buildBoardView(semesterMap, filterList)
              : _buildListView(semesterMap, filterList),
        ),
      ],
    );
  }

  Widget _buildBoardView(
    Map<int, List<Course>> semesterMap,
    List<Course> Function(List<Course>) filterFn,
  ) {
    final semesters = semesterMap.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxListHeight = (constraints.maxHeight - 110).clamp(250.0, 900.0);

        return SingleChildScrollView(
          controller: _boardScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: semesters.map((sem) {
              final courses = filterFn(semesterMap[sem] ?? []);
              final allCoursesInSem = semesterMap[sem] ?? [];
              final semCredits = allCoursesInSem.fold(0, (sum, c) => sum + c.credits);
              final semTitle = sem == 0 ? 'Học kỳ Chuẩn bị (Giai đoạn 0)' : 'Học kỳ $sem';

              return Container(
                width: 310,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: _selectedSemesterFilter == sem ? AppTheme.primaryBlue : AppTheme.slate200,
                    width: _selectedSemesterFilter == sem ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg - 1)),
                        border: Border(bottom: BorderSide(color: AppTheme.slate200)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                semTitle,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.slate900),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${courses.length} môn',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tổng tín chỉ: $semCredits TC',
                                style: TextStyle(fontSize: 12, color: AppTheme.slate600, fontWeight: FontWeight.w500),
                              ),
                              InkWell(
                                onTap: () => _showAdvisorDialog(semesterTitle: semTitle),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    'Tư vấn kỳ',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.accentOrange),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxListHeight),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(10),
                        itemCount: courses.length,
                        itemBuilder: (context, index) {
                          final course = courses[index];
                          return _buildCourseCard(course);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildListView(
    Map<int, List<Course>> semesterMap,
    List<Course> Function(List<Course>) filterFn,
  ) {
    final semesters = semesterMap.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: semesters.length,
      itemBuilder: (context, index) {
        final sem = semesters[index];
        final courses = filterFn(semesterMap[sem] ?? []);
        final semTitle = sem == 0 ? 'Học kỳ Chuẩn bị (Giai đoạn 0)' : 'Học kỳ $sem';
        final semCredits = (semesterMap[sem] ?? []).fold(0, (sum, c) => sum + c.credits);

        if (courses.isEmpty && _searchQuery.isNotEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            initiallyExpanded: _selectedSemesterFilter == null || _selectedSemesterFilter == sem,
            title: Row(
              children: [
                Text(
                  semTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 12),
                StatusBadge.credits(semCredits),
                const SizedBox(width: 8),
                Text(
                  '(${courses.length} môn)',
                  style: TextStyle(fontSize: 13, color: AppTheme.slate600),
                ),
              ],
            ),
            trailing: TextButton(
              onPressed: () => _showAdvisorDialog(semesterTitle: semTitle),
              child: const Text('Tư vấn kỳ này', style: TextStyle(color: AppTheme.accentOrange, fontSize: 12.5)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: courses.map((c) => SizedBox(width: 320, child: _buildCourseCard(c))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCourseCard(Course course) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverCard(
        padding: const EdgeInsets.all(12),
        borderRadius: AppTheme.radiusMd,
        onTap: () {
          CourseSummaryModal.showFromCourse(
            context,
            course: course,
            onDetailsPressed: () => _openCourseDetail(course.code),
            onAdvisorPressed: () => _showAdvisorDialog(courseCode: course.code),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    course.code,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryBlue),
                  ),
                ),
                Text(
                  '${course.credits} TC',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slate600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              course.nameVi.isNotEmpty ? course.nameVi : course.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.slate900),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (course.nameVi.isNotEmpty && course.name != course.nameVi) ...[
              const SizedBox(height: 2),
              Text(
                course.name,
                style: TextStyle(fontSize: 11.5, color: AppTheme.slate600, fontStyle: FontStyle.italic),
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
