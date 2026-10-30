import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_panel.dart';
import '../models/course.dart';
import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../state/learning_profile_provider.dart';
import '../services/learning_progress.dart';
import '../screens/transcript_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/breadcrumb_nav.dart';
import '../widgets/status_badge.dart';

class CourseDetailPage extends StatefulWidget {
  final String code;
  final String? curriculumId;

  const CourseDetailPage({super.key, required this.code, this.curriculumId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  bool _showRightChat = true;
  int _detailTab = 0;

  void _openSubjectChat(Course course) {
    if (MediaQuery.of(context).size.width >= 960) {
      setState(() => _showRightChat = true);
      return;
    }
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
            scope: 'subject',
            scopeId: course.code,
            title: 'Trợ lý Môn ${course.code}',
            subtitle: course.nameVi.isNotEmpty ? course.nameVi : course.name,
            onClose: () => Navigator.pop(sheetContext),
            suggestedQuestions: [
              'Tư vấn cách học môn ${course.code} theo mục tiêu của tôi và dữ liệu FLM.',
              'Tôi còn thiếu điều kiện gì để học ${course.code}?',
            ],
          ),
        ),
      ),
    );
  }

  void _showAdvisorDialog(Course course) {
    final transcript = context.read<TranscriptProvider>();
    final progress = LearningProgress(
      context.read<CourseCatalog>().courses,
      transcript.entries,
    ).status(course);
    final goal = context.read<LearningProfileProvider>().courseGoal;
    final assessments = course.assessmentScheme
        .where((item) => item.item != 'Chưa có dữ liệu đánh giá')
        .toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Tư vấn cách học môn ${course.code}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gợi ý chiến lược học tập cho môn ${course.nameVi.isNotEmpty ? course.nameVi : course.name} (${course.code}):',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                goal == 'pass'
                    ? 'Mục tiêu tự khai: qua môn. Ưu tiên kiểm tra điều kiện đạt thật trong đề cương và hoàn thành các thành phần bắt buộc.'
                    : goal == 'high_score'
                    ? 'Mục tiêu tự khai: điểm cao. Ưu tiên luyện theo CLO và tỷ trọng đánh giá có trong đề cương.'
                    : 'Bạn có thể đặt mục tiêu học tập trong Cài đặt để nhận chiến lược phù hợp hơn.',
              ),
              const SizedBox(height: 8),
              if (course.hasPe)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.peBadgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Dữ liệu FLM ghi môn này có PE. Hãy đối chiếu đề cương và luyện đúng nội dung, công cụ được ghi cho môn học.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.peBadgeText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (progress.missingPrerequisites.isNotEmpty)
                Text(
                  '• Còn thiếu trong bảng điểm: ${progress.missingPrerequisites.join(", ")}.',
                  style: const TextStyle(fontSize: 14, height: 1.3),
                ),
              if (progress.unverifiedPrerequisites.isNotEmpty)
                Text(
                  '• Cần xác minh mã tiên quyết: ${progress.unverifiedPrerequisites.join(", ")}. Không thể kết luận đủ điều kiện.',
                ),
              const SizedBox(height: 4),
              Text(
                assessments.isEmpty
                    ? '• Chưa có tỷ trọng đánh giá trong dữ liệu FLM của môn này.'
                    : '• Thành phần đánh giá theo FLM: ${assessments.map((item) => '${item.item} ${item.weight}').join('; ')}.',
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
              if (course.minPassMark.trim().isNotEmpty)
                Text(
                  '• Điều kiện đạt ghi trong dữ liệu môn học: ${course.minPassMark}.',
                ),
              const SizedBox(height: 8),
              Text(
                'Nguồn: dữ liệu môn ${course.code} trong FLM; điểm và trạng thái từ bảng điểm đã xác nhận trên thiết bị.',
              ),
            ],
          ),
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
            child: const Text('Hỏi AI chi tiết'),
            onPressed: () {
              Navigator.pop(ctx);
              _openSubjectChat(course);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    final course = catalog.findByCode(widget.code);
    final curId =
        widget.curriculumId ?? catalog.curriculum?.id ?? 'BIT_SE_K19B';

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: Text(
          course != null
              ? '${course.code} - ${course.nameVi.isNotEmpty ? course.nameVi : course.name}'
              : widget.code,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              BreadcrumbItem(label: curId, onTap: () => Navigator.pop(context)),
              BreadcrumbItem(label: course?.code ?? widget.code),
            ],
          ),

          // Main 2-column layout (Left: Syllabus Content, Right: Fixed Subject Chat Panel)
          Expanded(
            child: course == null
                ? Center(
                    child: Text(
                      catalog.isLoading
                          ? 'Đang tải dữ liệu môn học...'
                          : 'Không tìm thấy môn học ${widget.code}.',
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 960;
                      final showChatPanel = _showRightChat && isDesktop;

                      return Row(
                        children: [
                          // Left Column: Course Detail / Syllabus
                          Expanded(
                            flex: showChatPanel ? 65 : 100,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 900,
                                  ),
                                  child: _buildCourseContent(
                                    context,
                                    course,
                                    curId,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Right Column: Fixed Contextual Chat Panel
                          if (showChatPanel)
                            Expanded(
                              flex: 35,
                              child: ContextualChatPanel(
                                scope: 'subject',
                                scopeId: course.code,
                                title: 'Trợ lý Môn ${course.code}',
                                subtitle: course.nameVi.isNotEmpty
                                    ? course.nameVi
                                    : course.name,
                                onClose: () =>
                                    setState(() => _showRightChat = false),
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
          course == null ||
              (_showRightChat && MediaQuery.of(context).size.width >= 960)
          ? null
          : Tooltip(
              message: 'Hỏi Trợ lý AI (FLM Chatbot)',
              child: InkWell(
                onTap: () => _openSubjectChat(course),
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
                        color: const Color(0xFF6366F1).withValues(alpha: 0.42),
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

  Widget _buildCourseContent(
    BuildContext context,
    Course course,
    String curId,
  ) {
    final transcript = context.watch<TranscriptProvider>();
    final progress = LearningProgress(
      context.read<CourseCatalog>().courses,
      transcript.entries,
    ).status(course);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Hero Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        course.code,
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    StatusBadge.semester(course.semester),
                    StatusBadge.credits(course.credits),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Tư vấn môn này'),
                      onPressed: () => _showAdvisorDialog(course),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TranscriptScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Cập nhật điểm'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  course.nameVi.isNotEmpty ? course.nameVi : course.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slate900,
                  ),
                ),
                if (course.nameVi.isNotEmpty &&
                    course.name != course.nameVi) ...[
                  const SizedBox(height: 4),
                  Text(
                    course.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.slate600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusBadge.pe(hasPe: course.hasPe),
                    StatusBadge.gpa(countsInGpa: course.countsInGpa),
                  ],
                ),
                const SizedBox(height: 10),
                Text(switch (progress.readiness) {
                  CourseReadiness.completed =>
                    'Đã hoàn thành · Điểm ${progress.score?.toStringAsFixed(1) ?? 'chưa rõ'}',
                  CourseReadiness.inProgress => 'Đang học',
                  _ when !transcript.hasTranscript =>
                    'Chưa có bảng điểm để xác nhận điều kiện học',
                  CourseReadiness.ready =>
                    'Đủ tiên quyết theo bảng điểm đã nhập',
                  CourseReadiness.blocked =>
                    'Còn thiếu: ${progress.missingPrerequisites.join(', ')}',
                  CourseReadiness.unverified =>
                    'Cần xác minh: ${progress.unverifiedPrerequisites.join(', ')}',
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Section: "Xuất hiện trong (Appears In)" (Chương trình & Học kỳ)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xuất hiện trong chương trình đào tạo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (course.appearsIn.isEmpty)
                  Text(
                    'Chương trình $curId, Học kỳ ${course.semester}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Table(
                    border: TableBorder.all(color: AppTheme.slate200),
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1.5),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          color: AppTheme.slate100,
                        ),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Chương trình đào tạo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Học kỳ xuất hiện',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Số tín chỉ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (final app in course.appearsIn)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                app.curriculum,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                app.semester == 0
                                    ? 'Giai đoạn 0'
                                    : 'Học kỳ ${app.semester}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '${course.credits} TC',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        DefaultTabController(
          key: ValueKey(_detailTab),
          length: 3,
          initialIndex: _detailTab,
          child: TabBar(
            isScrollable: true,
            onTap: (index) => setState(() => _detailTab = index),
            tabs: const [
              Tab(text: 'Chuẩn đầu ra'),
              Tab(text: 'Điều kiện môn học'),
              Tab(text: 'Tiêu chí đánh giá'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_detailTab == 1) ...[
          // Section 1: Môn học tiên quyết & Kế tiếp
          _buildSectionHeader('1. Quan hệ môn học tiên quyết'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Môn học tiên quyết (Cần hoàn thành trước môn này):',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (course.prerequisites.isEmpty)
                    const Text(
                      'Không có môn ràng buộc tiên quyết',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: course.prerequisites.map((p) {
                        return ActionChip(
                          label: Text(
                            p,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailPage(
                                  code: p,
                                  curriculumId: curId,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  const Divider(height: 24),
                  const Text(
                    'Môn học kế tiếp (Môn này là điều kiện tiên quyết của):',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (course.unlocks.isEmpty)
                    const Text(
                      'Môn học giai đoạn cuối hoặc không ràng buộc',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: course.unlocks.map((u) {
                        return ActionChip(
                          label: Text(
                            u,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailPage(
                                  code: u,
                                  curriculumId: curId,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],

        if (_detailTab == 0) ...[
          // Section 2: Mục tiêu môn học & Chuẩn đầu ra (LOs)
          _buildSectionHeader(
            '2. Mục tiêu môn học & Chuẩn đầu ra (Learning Outcomes)',
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final outcome in course.learningOutcomes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                              fontSize: 16,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              outcome,
                              style: const TextStyle(
                                height: 1.35,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],

        if (_detailTab == 2) ...[
          // Section 3: Cấu trúc đánh giá & Hình thức thi (Assessment Scheme)
          _buildSectionHeader('3. Cấu trúc đánh giá & Hình thức thi'),
          const SizedBox(height: 10),
          Card(
            child: Table(
              border: TableBorder.all(color: AppTheme.slate200),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppTheme.slate100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Thành phần đánh giá',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Tỷ trọng (%)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Điểm tối thiểu',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                for (final item in course.assessmentScheme)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          item.item,
                          style: TextStyle(
                            fontWeight:
                                item.item.contains("PE") ||
                                    item.item.contains("FE")
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          item.weight,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(item.minMark),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],

        if (_detailTab == 1) ...[
          // Section 4: Dữ liệu Syllabus Chi Tiết
          _buildSectionHeader('4. Chi tiết đề cương môn học (FLM)'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Điểm qua môn tối thiểu:',
                    course.minPassMark,
                  ),
                  _buildDetailRow(
                    'Phân bổ thời gian học tập:',
                    course.timeAllocation,
                  ),
                  _buildDetailRow(
                    'Phương pháp giảng dạy:',
                    course.teachingMethods,
                  ),
                  _buildDetailRow('Nhiệm vụ sinh viên:', course.studentTasks),
                  _buildDetailRow(
                    'Công cụ & phần mềm thực hành:',
                    course.toolsSoftware,
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w800,
        color: AppTheme.slate900,
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.slate900,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.slate600,
              ),
            ),
            TextSpan(
              text: val.trim().isEmpty ? 'Chưa có dữ liệu trong FLM' : val,
            ),
          ],
        ),
      ),
    );
  }
}
