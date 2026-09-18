import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/course.dart';

class CourseRepository {
  Future<List<Course>> load() async {
    final source = await rootBundle.loadString('assets/courses_data.json');
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final rows = decoded['courses'] as List<dynamic>;
    return rows
        .map((row) => Course.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }
}
