import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/chat/providers/chat_provider.dart';
import 'pages/course_detail_page.dart';
import 'pages/curriculum_detail_page.dart';
import 'pages/curriculum_list_page.dart';
import 'state/course_catalog.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlmApp());
}

class FlmApp extends StatelessWidget {
  const FlmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourseCatalog()..load()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'FLM Knowledge & AI Assistant (Lab 1)',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        // Màn 1: Danh sách Curriculum (Mục 4.0 & Mục 4.1)
        home: const CurriculumListPage(),
        onGenerateRoute: (settings) {
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri != null && uri.pathSegments.isNotEmpty) {
            // Route: /curricula/:id -> Màn 2
            if (uri.pathSegments.first == 'curricula' && uri.pathSegments.length >= 2) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => CurriculumDetailPage(curriculumId: uri.pathSegments[1]),
              );
            }
            // Route: /courses/:code -> Màn 3
            if (uri.pathSegments.first == 'courses' && uri.pathSegments.length >= 2) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => CourseDetailPage(code: uri.pathSegments[1]),
              );
            }
          }
          return null;
        },
      ),
    );
  }
}
