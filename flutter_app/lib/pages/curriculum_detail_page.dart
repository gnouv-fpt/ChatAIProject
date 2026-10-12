import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_panel.dart';
import '../features/graph/views/graph_view_screen.dart';
import '../models/course.dart';
import '../models/curriculum.dart';
import '../models/transcript_entry.dart';
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
                          GraphViewScreen(
                            selectedCode: _selectedCourseCode,
                            onNodeSelected: (code) => setState(() => _selectedCourseCode = code),
                            onOpenDetail: _openCourseDetail,
                            onAdvisorRequested: (code) => _showAdvisorDialog(courseCode: code),
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

  int _selectedFilterSemester = 0; // 0: Tất cả học kỳ, 1-9: cụ thể
  String _selectedFilterType = 'all'; // 'all', 'pe', 'gpa', 'passed', 'failed'

  Widget _buildSubjectListTab(BuildContext context, CourseCatalog catalog, Curriculum curriculum) {
    final tp = context.watch<TranscriptProvider>();
    final hasTranscript = tp.hasTranscript;

    // Phân nhóm môn theo học kỳ
    final Map<int, List<Course>> semesterMap = {};
    for (int s = 1; s <= 9; s++) {
      semesterMap[s] = [];
    }
    for (final course in catalog.courses) {
      semesterMap.putIfAbsent(course.semester, () => []).add(course);
    }

    // Map điểm từ TranscriptEntry để tra cứu O(1)
    final Map<String, TranscriptEntry> gradeMap = {};
    if (hasTranscript) {
      for (final entry in tp.entries) {
        gradeMap[entry.courseCode] = entry;
      }
    }

    final query = _searchQuery.toLowerCase();
    bool passesFilter(Course c) {
      if (query.isNotEmpty) {
        final matchesQuery = c.code.toLowerCase().contains(query) ||
            c.name.toLowerCase().contains(query) ||
            c.nameVi.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }
      if (_selectedFilterType == 'pe' && !c.hasPe) return false;
      if (_selectedFilterType == 'gpa' && !c.countsInGpa) return false;
      
      final status = tp.getCourseStatus(c.code);
      if (_selectedFilterType == 'passed' && status != 'passed') return false;
      if (_selectedFilterType == 'retake' && status != 'retake') return false;
      if (_selectedFilterType == 'in_progress' && status != 'in_progress') return false;
      if (_selectedFilterType == 'not_started' && status != 'not_started') return false;

      return true;
    }

    // Thống kê tiến độ toàn khóa học (Tất cả các môn trong catalog)
    final allCourses = catalog.courses;
    final totalCatalogCredits = allCourses.fold(0, (sum, c) => sum + c.credits);
    int passedCredits = 0;
    int passedCount = 0;
    int retakeCount = 0;
    int inProgressCount = 0;
    int notStartedCount = 0;

    for (final c in allCourses) {
      final s = tp.getCourseStatus(c.code);
      if (s == 'passed') {
        passedCredits += c.credits;
        passedCount++;
      } else if (s == 'retake') {
        retakeCount++;
      } else if (s == 'in_progress') {
        inProgressCount++;
      } else {
        notStartedCount++;
      }
    }
    final double progressPercent = totalCatalogCredits > 0
        ? (passedCredits / totalCatalogCredits * 100).clamp(0.0, 100.0)
        : 0.0;

    // Danh sách các học kỳ cần hiển thị (0: tất cả, hoặc 1 cụ thể)
    final List<int> semestersToRender = _selectedFilterSemester == 0
        ? [1, 2, 3, 4, 5, 6, 7, 8, 9]
        : [_selectedFilterSemester];

    // Thống kê nhanh theo bộ lọc
    int totalVisibleCourses = 0;
    int totalVisibleCredits = 0;
    for (final s in semestersToRender) {
      final list = (semesterMap[s] ?? []).where(passesFilter).toList();
      totalVisibleCourses += list.length;
      totalVisibleCredits += list.fold(0, (sum, c) => sum + c.credits);
    }

    // Thống kê chính xác theo phạm vi học kỳ đang xem để các chip lọc hiển thị số lượng đúng ngữ cảnh
    final visibleCoursesInScope = _selectedFilterSemester == 0
        ? allCourses
        : (semesterMap[_selectedFilterSemester] ?? []);
    int scopePassedCount = 0;
    int scopeRetakeCount = 0;
    int scopeInProgressCount = 0;
    int scopeNotStartedCount = 0;
    for (final c in visibleCoursesInScope) {
      final s = tp.getCourseStatus(c.code);
      if (s == 'passed') {
        scopePassedCount++;
      } else if (s == 'retake') {
        scopeRetakeCount++;
      } else if (s == 'in_progress') {
        scopeInProgressCount++;
      } else {
        scopeNotStartedCount++;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Column(
          children: [
            // ── Toolbar Điều Khiển & Bộ Lọc Hiện Đại (Header HUD) ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.slate200, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dòng 1: Tìm kiếm + Thống kê số lượng + Nút Tư vấn Chiến lược HK
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: 'Tìm kiếm mã môn (PRM393, SWD392) hoặc tên môn...',
                              hintStyle: TextStyle(fontSize: 13, color: AppTheme.slate600.withValues(alpha: 0.7)),
                              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primaryBlue),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Thống kê môn / TC
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.library_books_outlined, size: 15, color: AppTheme.primaryBlue),
                            const SizedBox(width: 5),
                            Text(
                              '$totalVisibleCourses môn • $totalVisibleCredits TC',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nút Chiến lược HK đưa lên cùng hàng ngang bên phải
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF7ED),
                          foregroundColor: const Color(0xFFEA580C),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFFDBA74)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 15, color: Color(0xFFEA580C)),
                        label: Text(
                          _selectedFilterSemester == 0
                              ? 'Chiến lược toàn khóa'
                              : 'Chiến lược HK $_selectedFilterSemester',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          final title = _selectedFilterSemester == 0
                              ? 'toàn bộ chương trình đào tạo'
                              : 'Học kỳ $_selectedFilterSemester';
                          _showAdvisorDialog(semesterTitle: title);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Dòng 2: Thanh chuyển nhanh Học kỳ kiểu Segmented Timeline Track (Phân biệt rõ cấp độ Navigation)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Khung nền xám nhạt liền mạch
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildSemesterFilterChip(0, 'Tất cả 9 học kỳ', semesterMap),
                          const SizedBox(width: 4),
                          for (int s = 1; s <= 9; s++) ...[
                            _buildSemesterFilterChip(s, 'Học kỳ $s', semesterMap),
                            if (s < 9) const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 9),

                  // Dòng 3: Gộp chung Tiến Độ Toàn Khóa + Bộ Lọc Nhanh Semantic (Màu sắc và icon riêng biệt)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Cụm mini Tiến độ toàn khóa: Nền xanh dịu phân biệt rõ ràng
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school_rounded, size: 14, color: AppTheme.primaryBlue),
                              const SizedBox(width: 5),
                              Text(
                                'Tiến độ: $passedCredits/$totalCatalogCredits TC (${progressPercent.toStringAsFixed(0)}%)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 50,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: totalCatalogCredits > 0 ? (passedCredits / totalCatalogCredits) : 0,
                                    minHeight: 4,
                                    backgroundColor: const Color(0xFFDBEAFE),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),
                        Container(width: 1.2, height: 16, color: const Color(0xFFCBD5E1)),
                        const SizedBox(width: 10),

                        // Nhóm 1: Bộ lọc trạng thái học tập (Semantic Colors)
                        _buildTypeFilterChip('all', 'Tất cả', icon: Icons.apps_rounded),
                        const SizedBox(width: 6),
                        _buildTypeFilterChip(
                          'passed',
                          'Đã học ($scopePassedCount)',
                          baseColor: const Color(0xFF15803D),
                          bgTint: const Color(0xFFDCFCE7),
                          icon: Icons.check_circle_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildTypeFilterChip(
                          'in_progress',
                          'Đang học ($scopeInProgressCount)',
                          baseColor: const Color(0xFF1D4ED8),
                          bgTint: const Color(0xFFDBEAFE),
                          icon: Icons.hourglass_top_rounded,
                        ),
                        if (scopeRetakeCount > 0) ...[
                          const SizedBox(width: 6),
                          _buildTypeFilterChip(
                            'retake',
                            'Học lại ($scopeRetakeCount)',
                            baseColor: const Color(0xFFB91C1C),
                            bgTint: const Color(0xFFFEE2E2),
                            icon: Icons.error_outline_rounded,
                          ),
                        ],
                        const SizedBox(width: 6),
                        _buildTypeFilterChip(
                          'not_started',
                          'Chưa học ($scopeNotStartedCount)',
                          baseColor: const Color(0xFF64748B),
                          bgTint: const Color(0xFFF1F5F9),
                          icon: Icons.radio_button_unchecked_rounded,
                        ),

                        const SizedBox(width: 10),
                        Container(width: 1.2, height: 16, color: const Color(0xFFCBD5E1)),
                        const SizedBox(width: 10),

                        // Nhóm 2: Bộ lọc đặc tính môn học (PE & GPA)
                        _buildTypeFilterChip(
                          'pe',
                          'Có thi PE',
                          baseColor: const Color(0xFFD97706),
                          bgTint: const Color(0xFFFEF3C7),
                          icon: Icons.code_rounded,
                        ),
                        const SizedBox(width: 6),
                        _buildTypeFilterChip(
                          'gpa',
                          'Tính GPA',
                          baseColor: const Color(0xFF0D9488),
                          bgTint: const Color(0xFFCCFBF1),
                          icon: Icons.auto_graph_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Danh Sách Môn Học Lưới Phẳng (Đã bỏ khung thừa để đẩy môn học lên cao) ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                itemCount: semestersToRender.length,
                itemBuilder: (context, index) {
                  final sem = semestersToRender[index];
                  final allInSem = semesterMap[sem] ?? [];
                  final filteredCourses = allInSem.where(passesFilter).toList();

                  if (filteredCourses.isEmpty) {
                    return const SizedBox.shrink();
                  }

                    final bool isViewingAll = _selectedFilterSemester == 0;
                    final semCredits = filteredCourses.fold(0, (sum, c) => sum + c.credits);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Khi xem "Tất cả 9 học kỳ", hiển thị tiêu đề phân chia từng kỳ rõ ràng
                          if (isViewingAll) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.slate200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'HK $sem',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Học kỳ $sem',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.slate800,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${filteredCourses.length} môn • $semCredits TC)',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppTheme.slate600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Nút mở chiến lược học tập riêng cho từng kỳ trong view all
                                  InkWell(
                                    onTap: () => _showAdvisorDialog(semesterTitle: 'Học kỳ $sem'),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.auto_awesome, size: 13, color: Color(0xFFD97706)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Chiến lược HK $sem',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          LayoutBuilder(
                            builder: (context, cardConstraints) {
                              // >= 1150px: 4 cột | >= 800px: 3 cột | >= 500px: 2 cột | < 500px: 1 cột
                              final double w = cardConstraints.maxWidth;
                              final int crossAxisCount = w >= 1150
                                  ? 4
                                  : (w >= 800 ? 3 : (w >= 500 ? 2 : 1));
                              const double spacing = 12.0;
                              final double itemWidth = crossAxisCount == 1
                                  ? w
                                  : (w - (crossAxisCount - 1) * spacing) / crossAxisCount;

                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: filteredCourses.map((c) {
                                  return SizedBox(
                                    width: itemWidth,
                                    child: _buildProMaxCourseCard(c, gradeMap[c.code]),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSemesterFilterChip(int sem, String label, Map<int, List<Course>> semesterMap) {
    final isSelected = _selectedFilterSemester == sem;
    final count = sem == 0
        ? semesterMap.values.fold(0, (sum, l) => sum + l.length)
        : (semesterMap[sem]?.length ?? 0);

    return InkWell(
      onTap: () => setState(() => _selectedFilterSemester = sem),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryBlue : AppTheme.slate700,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFDBEAFE) : AppTheme.slate200.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.slate700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilterChip(
    String type,
    String label, {
    Color? baseColor,
    Color? bgTint,
    IconData? icon,
  }) {
    final isSelected = _selectedFilterType == type;
    final color = baseColor ?? AppTheme.primaryBlue;
    final bg = isSelected
        ? (bgTint ?? AppTheme.primaryLight)
        : (bgTint != null ? bgTint.withValues(alpha: 0.35) : Colors.white);
    final borderColor = isSelected
        ? color
        : (baseColor != null ? baseColor.withValues(alpha: 0.35) : const Color(0xFFCBD5E1));

    return InkWell(
      onTap: () => setState(() => _selectedFilterType = type),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? color : color.withValues(alpha: 0.85)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : AppTheme.slate800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatusStat(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Card Môn Học chuẩn UI/UX Pro Max: Tên môn to rõ, đồng nhất chiều cao, ghi rõ 'Tín chỉ', tích hợp Self-Check trạng thái
  Widget _buildProMaxCourseCard(Course course, TranscriptEntry? gradeEntry) {
    final tp = context.watch<TranscriptProvider>();
    final isSelected = course.code == _selectedCourseCode;
    final learningStatus = tp.getCourseStatus(course.code);

    // Xác định màu viền và màu nền tinh tế theo trạng thái học tập
    Color borderColor;
    Color cardBg;
    if (isSelected) {
      borderColor = AppTheme.primaryBlue;
      cardBg = AppTheme.primaryLight.withValues(alpha: 0.35);
    } else {
      switch (learningStatus) {
        case 'passed':
          borderColor = const Color(0xFF86EFAC); // Xanh lá dịu
          cardBg = const Color(0xFFF0FDF4); // Nền phớt xanh lá
          break;
        case 'retake':
          borderColor = const Color(0xFFFECACA); // Đỏ cam nhẹ
          cardBg = const Color(0xFFFEF2F2); // Nền phớt đỏ nhẹ
          break;
        case 'in_progress':
          borderColor = const Color(0xFFBFDBFE); // Xanh dương nhẹ
          cardBg = const Color(0xFFEFF6FF); // Nền phớt xanh dương
          break;
        case 'not_started':
        default:
          borderColor = const Color(0xFFE2E8F0);
          cardBg = Colors.white;
          break;
      }
    }

    return HoverCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      borderRadius: AppTheme.radiusMd,
      borderColor: borderColor,
      backgroundColor: cardBg,
      onTap: () {
        setState(() => _selectedCourseCode = course.code);
        _openCourseDetail(course.code);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dòng 1: Tag mã môn + Tín chỉ + Nút tương tác Trạng Thái Học Tập (Self-Check Menu)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primaryBlue, width: 1.4),
                ),
                child: Text(
                  course.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    fontSize: 17.5,
                    color: AppTheme.primaryDark,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${course.credits} Tín chỉ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
                ),
              ),
              const Spacer(),
              // Nút tự check / Menu đổi trạng thái học tập linh hoạt
              PopupMenuButton<String>(
                tooltip: 'Bấm để đổi trạng thái học tập môn này',
                onSelected: (newStatus) {
                  tp.setCourseStatus(course.code, newStatus);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'passed',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                        SizedBox(width: 8),
                        Text('Đã học (Pass)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'in_progress',
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text('Đang học (Current)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'retake',
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('Cần học lại (Retake)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'not_started',
                    child: Row(
                      children: [
                        Icon(Icons.radio_button_unchecked, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text('Chưa học (Reset)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: StatusBadge.learningStatus(
                    learningStatus,
                    score: gradeEntry?.score,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Dòng 2: Tên môn học lớn rõ ràng (15.5px) bắt mắt ngay khi nhìn vào
          SizedBox(
            height: 42, // Cố định chiều cao 2 dòng để toàn bộ thẻ đồng đều 100%
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.nameVi.isNotEmpty ? course.nameVi : course.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: AppTheme.slate900,
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  course.nameVi.isNotEmpty && course.name != course.nameVi
                      ? course.name
                      : (course.nameVi.isNotEmpty ? course.nameVi : ''),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate600,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Dòng 3: Thuộc tính cốt lõi (Thi PE & GPA) - Cố định chiều cao 24px
          SizedBox(
            height: 24,
            child: Row(
              children: [
                StatusBadge.pe(hasPe: course.hasPe),
                const SizedBox(width: 6),
                StatusBadge.gpa(countsInGpa: course.countsInGpa),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Dòng 4: Vùng Tiên Quyết chuyên biệt (Cố định chiều cao 24px, chỉ nổi bật khi có môn tiên quyết)
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: course.prerequisites.isNotEmpty
                  ? Tooltip(
                      message: 'Môn tiên quyết cần học trước: ${course.prerequisites.join(", ")}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.primaryBlue),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Tiên quyết: ${course.prerequisites.join(", ")}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryBlue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppTheme.slate200),
          const SizedBox(height: 6),

          // Dòng 4: Action row - Căn đều 2 nút bấm thao tác
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  CourseSummaryModal.showFromCourse(
                    context,
                    course: course,
                    onDetailsPressed: () => _openCourseDetail(course.code),
                    onAdvisorPressed: () => _showAdvisorDialog(courseCode: course.code),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.info_outline, size: 14, color: AppTheme.slate600),
                      SizedBox(width: 4),
                      Text('Tóm tắt', style: TextStyle(fontSize: 12, color: AppTheme.slate700)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() => _selectedCourseCode = course.code);
                  _openCourseDetail(course.code);
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Chi tiết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward, size: 14, color: AppTheme.primaryBlue),
                    ],
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
