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
import '../widgets/app_ui.dart';
import '../widgets/breadcrumb_nav.dart';
import '../widgets/course_visuals.dart';
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
      appBar: AppBar(title: const Text('Chi tiết môn học'), actions: const []),
      body: Column(
        children: [
          // Breadcrumb Navigation
          if (MediaQuery.sizeOf(context).width >= 600)
            BreadcrumbNav(
              items: [
                BreadcrumbItem(
                  label: 'Chương trình khung',
                  onTap: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                BreadcrumbItem(
                  label: curId,
                  onTap: () => Navigator.pop(context),
                ),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Column: Course Detail / Syllabus
                          Expanded(
                            flex: showChatPanel ? 65 : 100,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                96,
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
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
          : FloatingActionButton.small(
              tooltip: 'Hỏi trợ lý về môn này',
              onPressed: () => _openSubjectChat(course),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              child: const Icon(Icons.chat_bubble_outline_rounded),
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
    final readinessStyle = ReadinessStyle.of(
      progress.readiness,
      known: transcript.hasTranscript,
    );
    final readinessText = switch (progress.readiness) {
      CourseReadiness.completed =>
        'Đã hoàn thành · Điểm ${progress.score?.toStringAsFixed(1) ?? 'chưa rõ'}',
      CourseReadiness.inProgress => 'Đang học trong học kỳ hiện tại',
      _ when !transcript.hasTranscript =>
        'Chưa có bảng điểm để xác nhận điều kiện học',
      CourseReadiness.ready => 'Đủ tiên quyết theo bảng điểm đã nhập',
      CourseReadiness.blocked =>
        'Còn thiếu: ${progress.missingPrerequisites.join(', ')}',
      CourseReadiness.unverified =>
        'Cần xác minh: ${progress.unverifiedPrerequisites.join(', ')}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Hero Card
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${course.code}  ·  HỌC KỲ ${course.semester}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      course.nameVi.isNotEmpty ? course.nameVi : course.name,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.slate900,
                        height: 1.2,
                      ),
                    ),
                    if (course.nameVi.isNotEmpty &&
                        course.name != course.nameVi) ...[
                      const SizedBox(height: 5),
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.slate600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _courseFact(
                          Icons.school_outlined,
                          '${course.credits} tín chỉ',
                        ),
                        _courseFact(
                          Icons.fact_check_outlined,
                          course.hasPe ? 'Có PE' : 'Không PE',
                        ),
                        _courseFact(
                          Icons.insights_outlined,
                          course.countsInGpa ? 'Tính GPA' : 'Không tính GPA',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppTheme.slate200),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(140, 48),
                          ),
                          icon: const Icon(
                            Icons.auto_awesome_outlined,
                            size: 18,
                          ),
                          label: const Text('Tư vấn môn này'),
                          onPressed: () => _showAdvisorDialog(course),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(140, 48),
                          ),
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TranscriptScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note, size: 20),
                          label: const Text('Cập nhật điểm'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          readinessStyle.icon,
                          size: 18,
                          color: readinessStyle.fg,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            readinessText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: readinessStyle.fg,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (course.appearsIn.length > 1 ||
            course.appearsIn.any((entry) => entry.curriculum != curId)) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_tree_outlined,
                        size: 18,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Xuất hiện trong chương trình đào tạo',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: AppTheme.slate900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (course.appearsIn.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.slate50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Chương trình $curId',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate900,
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              StatusBadge.semester(course.semester),
                              StatusBadge.credits(course.credits),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    for (var i = 0; i < course.appearsIn.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.slate50,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          border: Border.all(color: AppTheme.slate200),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              course.appearsIn[i].curriculum,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                StatusBadge.semester(
                                  course.appearsIn[i].semester,
                                ),
                                StatusBadge.credits(course.credits),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.slate200)),
          ),
          child: DefaultTabController(
            key: ValueKey(_detailTab),
            length: 3,
            initialIndex: _detailTab,
            child: TabBar(
              isScrollable: false,
              dividerColor: Colors.transparent,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.slate600,
              indicatorColor: AppTheme.primaryBlue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              onTap: (index) => setState(() => _detailTab = index),
              tabs: const [
                Tab(text: 'Chuẩn đầu ra'),
                Tab(text: 'Tiên quyết'),
                Tab(text: 'Đánh giá'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (_detailTab == 1) ...[
          // Section: Môn học tiên quyết & Kế tiếp
          const SectionHeader(
            title: 'Quan hệ môn học tiên quyết',
            icon: Icons.hub_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Môn học tiên quyết (Cần hoàn thành trước môn này):',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (course.prerequisites.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.slate50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Text(
                        'Không có môn ràng buộc tiên quyết',
                        style: TextStyle(color: AppTheme.slate600),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: course.prerequisites.map((p) {
                        return ActionChip(
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          avatar: const Icon(
                            Icons.lock_open_rounded,
                            size: 16,
                            color: AppTheme.primaryBlue,
                          ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (course.unlocks.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.slate50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Text(
                        'Môn học giai đoạn cuối hoặc không ràng buộc',
                        style: TextStyle(color: AppTheme.slate600),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: course.unlocks.map((u) {
                        return ActionChip(
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          avatar: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Color(0xFF059669),
                          ),
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

          const SizedBox(height: 16),
        ],

        if (_detailTab == 0) ...[
          // Section: Mục tiêu môn học & Chuẩn đầu ra (LOs)
          const SectionHeader(
            title: 'Chuẩn đầu ra của môn học',
            icon: Icons.verified_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: course.learningOutcomes.isEmpty
                  ? const Text(
                      'Chưa có dữ liệu chuẩn đầu ra trong FLM.',
                      style: TextStyle(color: AppTheme.slate600),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var i = 0;
                          i < course.learningOutcomes.length;
                          i++
                        ) ...[
                          if (i > 0)
                            const Divider(height: 20, color: AppTheme.slate200),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryBlue,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  course.learningOutcomes[i],
                                  style: const TextStyle(
                                    height: 1.55,
                                    fontSize: 14,
                                    color: AppTheme.slate900,
                                    letterSpacing: 0.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),
        ],

        if (_detailTab == 2) ...[
          // Section: Cấu trúc đánh giá & Hình thức thi (Assessment Scheme)
          const SectionHeader(
            title: 'Cấu trúc đánh giá & Hình thức thi',
            icon: Icons.fact_check_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: course.assessmentScheme.isEmpty
                  ? const Text(
                      'Chưa có dữ liệu đánh giá trong FLM.',
                      style: TextStyle(color: AppTheme.slate600),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var i = 0;
                          i < course.assessmentScheme.length;
                          i++
                        ) ...[
                          if (i > 0)
                            const Divider(height: 20, color: AppTheme.slate200),
                          Builder(
                            builder: (context) {
                              final item = course.assessmentScheme[i];
                              final isExam =
                                  item.item.contains('PE') ||
                                  item.item.contains('FE');
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.item,
                                          style: TextStyle(
                                            fontWeight: isExam
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 14.5,
                                            color: AppTheme.slate900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Điểm tối thiểu: ${item.minMark.isEmpty ? "0" : item.minMark}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.slate600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isExam
                                          ? AppTheme.peBadgeBg
                                          : AppTheme.primaryLight,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      item.weight,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: isExam
                                            ? AppTheme.peBadgeText
                                            : AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),
        ],

        if (_detailTab == 1) ...[
          // Section: Dữ liệu Syllabus Chi Tiết
          const SectionHeader(
            title: 'Chi tiết đề cương môn học (FLM)',
            icon: Icons.menu_book_outlined,
          ),
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
                  const Divider(height: 20, color: AppTheme.slate200),
                  _buildDetailRow(
                    'Phân bổ thời gian học tập:',
                    course.timeAllocation,
                  ),
                  const Divider(height: 20, color: AppTheme.slate200),
                  _buildDetailRow(
                    'Phương pháp giảng dạy:',
                    course.teachingMethods,
                  ),
                  const Divider(height: 20, color: AppTheme.slate200),
                  _buildDetailRow('Nhiệm vụ sinh viên:', course.studentTasks),
                  const Divider(height: 20, color: AppTheme.slate200),
                  _buildDetailRow(
                    'Công cụ & phần mềm thực hành:',
                    course.toolsSoftware,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _courseFact(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.slate600),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.slate700),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.slate600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val.trim().isEmpty ? 'Chưa có dữ liệu trong FLM' : val,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.slate900,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
