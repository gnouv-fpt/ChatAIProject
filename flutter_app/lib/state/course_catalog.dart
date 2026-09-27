import 'package:flutter/foundation.dart';

import '../data/course_repository.dart';
import '../models/course.dart';
import '../models/curriculum.dart';

class CourseCatalog extends ChangeNotifier {
  CourseCatalog();

  final _repository = CourseRepository();
  
  Curriculum? curriculum;
  List<CurriculumHeader> curricula = const [];
  List<SemesterData> semesters = const [];
  List<PloItem> plos = const [];
  List<Course> courses = const [];
  
  bool isLoading = false;
  String? error;

  Course? findByCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    for (final course in courses) {
      if (course.code.toUpperCase() == cleanCode || course.codeOriginal.toUpperCase() == cleanCode) {
        return course;
      }
    }
    return null;
  }

  List<Course> getCoursesBySemester(int semester) {
    return courses.where((c) => c.semester == semester).toList();
  }

  int get totalCreditsInGpa {
    return courses.where((c) => c.countsInGpa).fold(0, (sum, c) => sum + c.credits);
  }

  int get totalCredits {
    return courses.fold(0, (sum, c) => sum + c.credits);
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _repository.loadData();
      curriculum = data.curriculum;
      curricula = data.curricula;
      semesters = data.semesters;
      plos = data.plos;
      courses = data.courses;
    } catch (failure) {
      debugPrint('Không thể tải courses_data.json: $failure');
      error = 'Không thể đọc dữ liệu môn học. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
