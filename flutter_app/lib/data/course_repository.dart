import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/curriculum.dart';

class CourseCatalogData {
  final Curriculum curriculum;
  final List<CurriculumHeader> curricula;
  final List<SemesterData> semesters;
  final List<PloItem> plos;
  final List<Course> courses;

  const CourseCatalogData({
    required this.curriculum,
    required this.curricula,
    required this.semesters,
    required this.plos,
    required this.courses,
  });
}

class CourseRepository {
  Future<CourseCatalogData> loadData() async {
    final source = await rootBundle.loadString('assets/courses_data.json');
    final decoded = jsonDecode(source) as Map<String, dynamic>;

    // 1. Curriculum & Curricula list (Không hardcode)
    final curMap = decoded['curriculum'] as Map<String, dynamic>? ?? {};
    final curriculum = Curriculum.fromJson(curMap);

    final curricula = <CurriculumHeader>[];
    if (curMap['curricula'] != null && curMap['curricula'] is List) {
      for (final item in curMap['curricula'] as List) {
        if (item is Map<String, dynamic>) {
          curricula.add(CurriculumHeader.fromJson(item));
        }
      }
    }
    if (curricula.isEmpty) {
      curricula.add(CurriculumHeader(
        id: curriculum.id,
        name: curriculum.name,
        nameVi: curriculum.nameVi,
      ));
    }

    // 2. Semesters metadata
    final semesters = <SemesterData>[];
    if (decoded['semesters'] != null && decoded['semesters'] is List) {
      for (final s in decoded['semesters'] as List) {
        if (s is Map<String, dynamic>) {
          semesters.add(SemesterData.fromJson(s));
        }
      }
    }

    // 3. PLOs
    final plos = <PloItem>[];
    if (decoded['plos'] != null && decoded['plos'] is List) {
      for (final p in decoded['plos'] as List) {
        if (p is Map<String, dynamic>) {
          plos.add(PloItem.fromJson(p));
        }
      }
    }

    // 4. Courses list
    final rows = (decoded['courses'] as List<dynamic>?) ?? [];
    final courses = rows
        .map((row) => Course.fromJson(row as Map<String, dynamic>))
        .where((c) => c.inCurriculum) // Lọc bỏ alias không trong curriculum khi hiển thị chính
        .toList(growable: false);

    return CourseCatalogData(
      curriculum: curriculum,
      curricula: curricula,
      semesters: semesters,
      plos: plos,
      courses: courses,
    );
  }

  /// Tương thích ngược
  Future<List<Course>> load() async {
    final data = await loadData();
    return data.courses;
  }
}
