import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/curriculum.dart';
import '../state/course_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/hover_card.dart';
import 'curriculum_detail_page.dart';

class CurriculumListPage extends StatelessWidget {
  const CurriculumListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: const Text(
          'FLM Curriculum & Knowledge Base',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: catalog.load,
            child: const Text('Tải lại dữ liệu', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: catalog.isLoading && catalog.curriculum == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang nạp dữ liệu chương trình khung từ FLM...'),
                ],
              ),
            )
          : catalog.error != null && catalog.curriculum == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(catalog.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: catalog.load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(context, catalog),
    );
  }

  Widget _buildContent(BuildContext context, CourseCatalog catalog) {
    final curriculum = catalog.curriculum;
    if (curriculum == null) {
      return const Center(child: Text('Không tìm thấy chương trình đào tạo.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner / Hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF0288D1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'FLM Knowledge Assistant - Lab 1',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hệ thống Quản lý Khung Chương trình\nvà Đề cương Môn học (FLM)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Xem chương trình khung, khám phá sơ đồ quan hệ tiên quyết Obsidian Graph, hỏi đáp AI RAG theo ngữ cảnh và tư vấn lộ trình học tập cá nhân.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Danh sách Chương trình Đào tạo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dữ liệu được trích xuất động từ FLM FPT University',
                        style: TextStyle(fontSize: 13.5, color: AppTheme.slate600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${catalog.curricula.length} Chương trình',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Curriculum Cards List
              for (final header in catalog.curricula) ...[
                _CurriculumCard(
                  header: header,
                  curriculum: curriculum,
                  courseCount: catalog.courses.length,
                  totalCredits: catalog.totalCredits,
                  totalCreditsInGpa: catalog.totalCreditsInGpa,
                  onSelect: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CurriculumDetailPage(curriculumId: header.id),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CurriculumCard extends StatelessWidget {
  final CurriculumHeader header;
  final Curriculum curriculum;
  final int courseCount;
  final int totalCredits;
  final int totalCreditsInGpa;
  final VoidCallback onSelect;

  const _CurriculumCard({
    required this.header,
    required this.curriculum,
    required this.courseCount,
    required this.totalCredits,
    required this.totalCreditsInGpa,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: onSelect,
      padding: const EdgeInsets.all(24),
      borderRadius: AppTheme.radiusXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Top: Code & Badge Major
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Text(
                  header.id,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  curriculum.major,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Xem chi tiết',
                style: TextStyle(fontSize: 13, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Titles
          Text(
            header.nameVi.isNotEmpty ? header.nameVi : header.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            header.name,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.slate600,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 20),

          // 4 Key Metrics Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  label: 'Số học kỳ',
                  value: '${curriculum.semesterCount} Kỳ',
                  color: const Color(0xFF2563EB),
                ),
                _buildDivider(),
                _buildMetric(
                  label: 'Số môn học',
                  value: '$courseCount Môn',
                  color: const Color(0xFF059669),
                ),
                _buildDivider(),
                _buildMetric(
                  label: 'Tổng tín chỉ',
                  value: '$totalCredits TC',
                  color: const Color(0xFFD97706),
                ),
                _buildDivider(),
                _buildMetric(
                  label: 'Tín chỉ tính GPA',
                  value: '$totalCreditsInGpa TC',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Footer info
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quyết định: ${curriculum.decisionNo} - ${curriculum.degreeLevel}',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.slate600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onSelect,
                child: const Text('Khám phá khung', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.slate600, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 32,
      color: AppTheme.slate200,
    );
  }
}
