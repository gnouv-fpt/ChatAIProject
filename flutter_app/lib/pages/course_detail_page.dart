import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_panel.dart';
import '../models/course.dart';
import '../state/course_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/breadcrumb_nav.dart';
import '../widgets/status_badge.dart';

class CourseDetailPage extends StatefulWidget {
  final String code;
  final String? curriculumId;

  const CourseDetailPage({
    super.key,
    required this.code,
    this.curriculumId,
  });

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  bool _showRightChat = true;

  void _showAdvisorDialog(Course course) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Tư vấn cách học môn ${course.code}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gợi ý chiến lược học tập cho môn ${course.nameVi.isNotEmpty ? course.nameVi : course.name} (${course.code}):',
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 10),
            if (course.hasPe)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.peBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Môn này có bài thi thực hành PE. Sinh viên cần chủ động thực hành viết code trên môi trường thực tế và hoàn thành đầy đủ các bài lab.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.peBadgeText, fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(height: 8),
            if (course.prerequisites.isNotEmpty)
              Text(
                '• Kiến thức nền tảng cần nắm chắc: ${course.prerequisites.join(", ")}.',
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
            const SizedBox(height: 4),
            Text(
              '• Tỷ trọng thi cuối kỳ (FE): ${course.assessmentScheme.any((a) => a.item.contains("FE") || a.item.contains("Final")) ? "Theo bảng đánh giá chi tiết" : "50%"}.',
              style: const TextStyle(fontSize: 13, height: 1.3),
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
            child: const Text('Hỏi AI chi tiết'),
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
    final course = catalog.findByCode(widget.code);
    final curId = widget.curriculumId ?? catalog.curriculum?.id ?? 'BIT_SE_K19B';

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
              BreadcrumbItem(
                label: curId,
                onTap: () => Navigator.pop(context),
              ),
              BreadcrumbItem(
                label: course?.code ?? widget.code,
              ),
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
                                  constraints: const BoxConstraints(maxWidth: 900),
                                  child: _buildCourseContent(context, course, curId),
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
                                subtitle: course.nameVi.isNotEmpty ? course.nameVi : course.name,
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
                          scope: 'subject',
                          scopeId: course?.code ?? widget.code,
                          title: 'Trợ lý Môn ${course?.code ?? widget.code}',
                          subtitle: course?.nameVi.isNotEmpty == true ? course!.nameVi : course?.name,
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

  Widget _buildCourseContent(BuildContext context, Course course, String curId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Hero Card Tổng Quan Môn Học (Modern Academic Banner) ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.slate200, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Code badge, Semester, Credits & Advisor Action
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      course.code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusBadge.semester(course.semester),
                  const SizedBox(width: 8),
                  StatusBadge.credits(course.credits),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Tư vấn môn này', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _showAdvisorDialog(course),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title tiếng Việt & Tiếng Anh
              Text(
                course.nameVi.isNotEmpty ? course.nameVi : course.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.slate900,
                  height: 1.3,
                ),
              ),
              if (course.nameVi.isNotEmpty && course.name != course.nameVi) ...[
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

              // Attribute Badges
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusBadge.pe(hasPe: course.hasPe),
                  StatusBadge.gpa(countsInGpa: course.countsInGpa),
                  if (course.minPassMark.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppTheme.slate100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        'Điểm qua môn: ${course.minPassMark}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.slate700),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── 2. Quan Hệ Môn Học (Tiên Quyết & Mở Khóa Tiếp Theo) ──
        _buildSectionHeader('1. Lộ trình & Quan hệ môn học tiên quyết', Icons.account_tree_outlined),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.slate200, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 18, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Môn học tiên quyết (Bắt buộc hoàn thành trước khi học môn này):',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.slate900),
                        ),
                        const SizedBox(height: 8),
                        if (course.prerequisites.isEmpty)
                          const Text('Không có môn tiên quyết (Có thể học ngay khi vào kỳ)', style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic, fontSize: 13))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: course.prerequisites.map((p) {
                              return ActionChip(
                                avatar: const Icon(Icons.check_circle_outline, size: 15, color: AppTheme.primaryBlue),
                                label: Text(p, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryBlue, fontFamily: 'monospace')),
                                backgroundColor: AppTheme.primaryLight,
                                side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CourseDetailPage(code: p, curriculumId: curId),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: AppTheme.slate200),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Môn học mở khóa kế tiếp (Môn này là điều kiện tiên quyết cho):',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.slate900),
                        ),
                        const SizedBox(height: 8),
                        if (course.unlocks.isEmpty)
                          const Text('Môn học giai đoạn cuối hoặc không chặn môn sau', style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic, fontSize: 13))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: course.unlocks.map((u) {
                              return ActionChip(
                                avatar: const Icon(Icons.lock_open, size: 15, color: Color(0xFF059669)),
                                label: Text(u, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF059669), fontFamily: 'monospace')),
                                backgroundColor: const Color(0xFFECFDF5),
                                side: BorderSide(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CourseDetailPage(code: u, curriculumId: curId),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── 3. Cấu Trúc Đánh Giá & Hình Thức Thi (Ma Trận Assessment Scheme) ──
        _buildSectionHeader('2. Cấu trúc đánh giá & Hình thức thi (Syllabus Grading Scheme)', Icons.fact_check_outlined),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.slate200, width: 1.2),
          ),
          child: course.assessmentScheme.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Chưa có thông tin đánh giá chi tiết trong đề cương FLM.', style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.slate600)),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg - 1),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppTheme.slate100),
                        children: const [
                          Padding(padding: EdgeInsets.all(12), child: Text('Thành phần đánh giá', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Trọng số (%)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                          Padding(padding: EdgeInsets.all(12), child: Text('Điểm tối thiểu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                        ],
                      ),
                      for (final item in course.assessmentScheme) ...[
                        TableRow(
                          decoration: BoxDecoration(
                            color: item.item.toUpperCase().contains("PE") || item.item.toUpperCase().contains("FE")
                                ? AppTheme.primaryLight.withValues(alpha: 0.15)
                                : Colors.white,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  if (item.item.toUpperCase().contains("PE"))
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.peBadgeBg, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('PE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.peBadgeText)),
                                    ),
                                  Expanded(
                                    child: Text(
                                      item.item,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: item.item.toUpperCase().contains("PE") || item.item.toUpperCase().contains("FE")
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                item.weight,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primaryBlue),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                item.minMark,
                                style: TextStyle(fontSize: 13, color: AppTheme.slate700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
        ),

        const SizedBox(height: 24),

        // ── 4. Mục Tiêu Môn Học & Chuẩn Đầu Ra (Learning Outcomes) ──
        _buildSectionHeader('3. Mục tiêu & Chuẩn đầu ra (Course Learning Outcomes)', Icons.school_outlined),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.slate200, width: 1.2),
          ),
          child: course.learningOutcomes.isEmpty
              ? const Text('Chưa có danh sách Learning Outcomes.', style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.slate600))
              : Column(
                  children: [
                    for (int i = 0; i < course.learningOutcomes.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i < course.learningOutcomes.length - 1 ? 12 : 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'LO${i + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryBlue, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                course.learningOutcomes[i],
                                style: const TextStyle(height: 1.4, fontSize: 13.5, color: AppTheme.slate900),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),

        const SizedBox(height: 24),

        // ── 5. Chi Tiết Đề Cương Khác (FLM Technical Spec) ──
        _buildSectionHeader('4. Chi tiết đề cương môn học (FLM)', Icons.description_outlined),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.slate200, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Thang điểm:', '10'),
              _buildDetailRow('Điểm qua môn tối thiểu:', course.minPassMark.isNotEmpty ? course.minPassMark : '5.0/10'),
              _buildDetailRow('Phân bổ thời gian:', course.timeAllocation.isNotEmpty ? course.timeAllocation : 'Theo phân bổ chuẩn FLM'),
              _buildDetailRow('Phương pháp giảng dạy:', course.teachingMethods.isNotEmpty ? course.teachingMethods : 'Blended Learning / Thực hành Lab'),
              _buildDetailRow('Nhiệm vụ sinh viên:', course.studentTasks.isNotEmpty ? course.studentTasks : 'Hoàn thành bài tập, lab, đồ án theo tiến độ'),
              _buildDetailRow('Công cụ & phần mềm:', course.toolsSoftware.isNotEmpty ? course.toolsSoftware : 'IDE và công cụ theo syllabus'),
            ],
          ),
        ),

        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.slate900,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slate600)),
          ),
          Expanded(
            child: Text(val, style: const TextStyle(fontSize: 13.5, color: AppTheme.slate900, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
