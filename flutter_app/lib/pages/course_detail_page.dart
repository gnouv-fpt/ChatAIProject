import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/course_catalog.dart';

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    final course = catalog.findByCode(code);

    return Scaffold(
      appBar: AppBar(
        title: Text('${course?.code ?? code} - Chi tiết môn học'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: course == null
          ? Center(
              child: Text(
                catalog.isLoading
                    ? 'Đang tải dữ liệu môn học...'
                    : 'Không tìm thấy môn học $code.',
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Title Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  course.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  course.nameVi.isNotEmpty ? course.nameVi : course.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${course.code} - ${course.nameVi} (${course.name})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• Chuyên ngành: Kỹ thuật Phần mềm (Software Engineering - SE)\n'
                            '• Chương trình đào tạo: BIT_SE_K19B\n'
                            '• Học kỳ: Học kỳ ${course.semester} | Số tín chỉ: ${course.credits} tín chỉ',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Obsidian Properties Card (Properties like Screenshot 1)
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: const Row(
                      children: [
                        Icon(Icons.tune, size: 20, color: Colors.indigo),
                        SizedBox(width: 8),
                        Text(
                          'Properties (Thông số metadata Obsidian)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.5),
                            1: FlexColumnWidth(4.0),
                          },
                          children: [
                            _buildPropRow('code', course.code),
                            _buildPropRow('code_original', course.codeOriginal),
                            _buildPropRow('name_en', course.name),
                            _buildPropRow('name_vi', course.nameVi.isNotEmpty ? course.nameVi : course.name),
                            _buildPropRow('credits', '${course.credits}'),
                            _buildPropRow('semester', '${course.semester}'),
                            _buildPropRow(
                              'prerequisites',
                              course.prerequisites.isEmpty ? 'Không' : course.prerequisites.join(', '),
                            ),
                            _buildPropRow(
                              'unlocks',
                              course.unlocks.isEmpty ? 'Môn giai đoạn cuối' : course.unlocks.join(', '),
                            ),
                            _buildPropRow('curriculum', 'BIT_SE_K19B'),
                            _buildPropRow('syllabus_url', course.syllabusUrl),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Section 1: Thông tin tổng quan môn học (Screenshot 2)
                  _buildSectionHeader('📌 1. Thông Tin Tổng Quan Môn Học'),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(3),
                    },
                    children: [
                      _buildTableRow('Mã môn học', course.code),
                      _buildTableRow('Tên tiếng Việt', course.nameVi.isNotEmpty ? course.nameVi : course.name),
                      _buildTableRow('Tên tiếng Anh', course.name),
                      _buildTableRow('Số tín chỉ', '${course.credits} tín chỉ'),
                      _buildTableRow('Học kỳ đề xuất', 'Học kỳ ${course.semester}'),
                      _buildTableRow('Điều kiện tiên quyết gốc', course.prerequisiteRaw.isNotEmpty ? course.prerequisiteRaw : (course.prerequisites.isEmpty ? 'Không' : course.prerequisites.join(', '))),
                      _buildTableRow('Link FLM Syllabus', 'Xem trên hệ thống FLM FPT'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Sơ đồ mối quan hệ tri thức (Screenshot 3)
                  _buildSectionHeader('🔗 2. Sơ Đồ Mối Quan Hệ Tri Thức (Knowledge Graph Links)'),
                  const SizedBox(height: 10),
                  const Text('⬅️ Môn học tiên quyết (Cần hoàn thành trước môn này):', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (course.prerequisites.isEmpty)
                    const Text('   Không (Môn cơ sở / nhập môn)', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      children: course.prerequisites.map((p) {
                        return ActionChip(
                          avatar: const Icon(Icons.arrow_back, size: 14),
                          label: Text(p, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CourseDetailPage(code: p)),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  const Text('➡️ Môn học kế tiếp (Môn này là điều kiện tiên quyết của):', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (course.unlocks.isEmpty)
                    const Text('   Môn học giai đoạn cuối hoặc không ràng buộc', style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      children: course.unlocks.map((u) {
                        return ActionChip(
                          avatar: const Icon(Icons.arrow_forward, size: 14),
                          label: Text(u, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CourseDetailPage(code: u)),
                            );
                          },
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),

                  // Section 3: Mục tiêu môn học & Chuẩn đầu ra (Screenshot 3 & 4)
                  _buildSectionHeader('🎯 3. Mục Tiêu Môn Học & Chuẩn Đầu Ra (Learning Outcomes)'),
                  const SizedBox(height: 8),
                  Text(
                    'Môn học ${course.code} trang bị cho sinh viên các kiến thức và kỹ năng đáp ứng các chuẩn đầu ra ngành Kỹ thuật phần mềm (PLO):',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 8),
                  for (final outcome in course.learningOutcomes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          Expanded(child: Text(outcome, style: const TextStyle(height: 1.3))),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Section 4: Cấu trúc đánh giá & Hình thức thi (Screenshot 4)
                  _buildSectionHeader('📊 4. Cấu Trúc Đánh Giá & Hình Thức Thi (Assessment Scheme)'),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.blue.shade50),
                        children: const [
                          Padding(padding: EdgeInsets.all(8), child: Text('Thành Phần Đánh Giá', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Tỷ Trọng (%)', style: TextStyle(fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(8), child: Text('Điểm Tối Thiểu', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      for (final item in course.assessmentScheme)
                        TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text(item.item)),
                            Padding(padding: const EdgeInsets.all(8), child: Text(item.weight, style: const TextStyle(fontWeight: FontWeight.bold))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(item.minMark)),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Section 5: Dữ liệu Syllabus Chi Tiết (Screenshot 4)
                  _buildSectionHeader('🔬 5. Dữ Liệu Syllabus Chi Tiết (FLM FPT University)'),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Thang điểm:', '10'),
                          _buildDetailRow('Điểm trung bình tối thiểu để qua môn (MinAvgMarkToPass):', course.minPassMark),
                          _buildDetailRow('Phân bổ thời gian (Time Allocation):', course.timeAllocation),
                          _buildDetailRow('Phương pháp giảng dạy:', course.teachingMethods),
                          _buildDetailRow('Yêu cầu chuyên cần (Student Tasks):', course.studentTasks),
                          _buildDetailRow('Công cụ & phần mềm yêu cầu (Tools & Software):', course.toolsSoftware),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0D47A1),
      ),
    );
  }

  TableRow _buildPropRow(String key, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.indigo)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(value, style: const TextStyle(fontSize: 12.5)),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String title, String detail) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(detail, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            TextSpan(text: val),
          ],
        ),
      ),
    );
  }
}
