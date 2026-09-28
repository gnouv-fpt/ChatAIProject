import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_panel.dart';
import '../features/graph/views/graph_view_screen.dart';
import '../models/course.dart';
import '../models/curriculum.dart';
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

  String _searchQuery = '';
  int? _expandedSemester;
  bool _showRightChat = true;
  String? _advisorPrompt;

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
    super.dispose();
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

  /// Mở chat panel và gợi câu hỏi tư vấn chiến lược theo học kỳ hoặc môn.
  /// Dữ kiện GPA được tính bằng code (GradeCalculator) và gửi kèm trong student_context.
  void _showAdvisorDialog({String? semesterTitle, String? courseCode}) {
    final tp = context.read<TranscriptProvider>();
    // Build suggested question để người dùng có thể hỏi chat
    String suggestedQuestion;
    if (courseCode != null) {
      suggestedQuestion = 'Tư vấn cách học và ôn thi môn $courseCode để đạt điểm cao.';
    } else if (semesterTitle != null) {
      suggestedQuestion = 'Chiến lược học tập và phân bổ thời gian trong $semesterTitle. Tôi nên ưu tiên môn nào?';
    } else {
      final hasData = tp.hasTranscript;
      final eval = hasData ? tp.evaluation : null;
      suggestedQuestion = hasData
          ? 'GPA hiện tại của tôi là ${eval!.currentGpa}. Mục tiêu tốt nghiệp ${tp.targetGpa}. Tôi cần làm gì từ giờ đến cuối?'
          : 'Tư vấn lộ trình học tập toàn khóa dựa trên chương trình đào tạo. Tôi chưa import bảng điểm.';
    }

    // Mở chat panel trước
    setState(() {
      _showRightChat = true;
      _advisorPrompt = suggestedQuestion;
    });

    // Sau đó hiện SnackBar với câu hỏi gợi ý
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gợi ý câu hỏi cho Chat AI:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('"$suggestedQuestion"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
          duration: const Duration(seconds: 7),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    });
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
                          semesterNumber: _expandedSemester,
                          suggestedQuestions: _advisorPrompt == null ? null : [_advisorPrompt!],
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
                          semesterNumber: _expandedSemester,
                          suggestedQuestions: _advisorPrompt == null ? null : [_advisorPrompt!],
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

              // ── Bảng điểm & Chiến lược (Mục 7) ─────────────────────
              GradeStrategyPanel(
                curriculumId: widget.curriculumId,
                onAdvisorPrompt: (prompt) {
                  setState(() {
                    _showRightChat = true;
                    _advisorPrompt = prompt;
                  });
                },
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
    for (int s = 1; s <= 9; s++) {
      semesterMap[s] = [];
    }
    for (final course in catalog.courses) {
      semesterMap.putIfAbsent(course.semester, () => []).add(course);
    }

    final query = _searchQuery.toLowerCase();
    List<Course> filterList(List<Course> list) => list.where((c) {
          if (query.isEmpty) return true;
          return c.code.toLowerCase().contains(query) ||
              c.name.toLowerCase().contains(query) ||
              c.nameVi.toLowerCase().contains(query);
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
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.slate200),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 9,
            itemBuilder: (context, index) {
              final sem = index + 1;
              final allCourses = semesterMap[sem] ?? const <Course>[];
              final courses = filterList(allCourses);
              final credits = allCourses.fold<int>(0, (sum, course) => sum + course.credits);
              final title = 'Học kỳ $sem';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  initiallyExpanded: _expandedSemester == sem,
                  onExpansionChanged: (expanded) => setState(() {
                    _expandedSemester = expanded ? sem : null;
                  }),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${allCourses.length} môn • $credits tín chỉ'),
                  trailing: IconButton(
                    tooltip: 'Tư vấn học kỳ',
                    icon: const Icon(Icons.auto_awesome_outlined, color: AppTheme.accentOrange),
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
                          child: Text('Không có môn phù hợp với nội dung tìm kiếm.'),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(children: courses.map(_buildCourseCard).toList()),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
