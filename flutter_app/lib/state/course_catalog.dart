import 'package:flutter/foundation.dart';

import '../data/course_repository.dart';
import '../models/course.dart';

class CourseCatalog extends ChangeNotifier {
  CourseCatalog();

  final _repository = CourseRepository();
  List<Course> courses = const [];
  bool isLoading = false;
  String? error;

  Course? findByCode(String code) {
    for (final course in courses) {
      if (course.code == code) return course;
    }
    return null;
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      courses = await _repository.load();
    } catch (failure) {
      debugPrint('Không thể tải courses_data.json: $failure');
      error = 'Không thể đọc dữ liệu môn học. Vui lòng thử lại.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
