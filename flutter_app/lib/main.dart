import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/chat/providers/chat_provider.dart';
import 'app/app_shell.dart';
import 'pages/course_detail_page.dart';
import 'pages/curriculum_detail_page.dart';
import 'state/course_catalog.dart';
import 'state/transcript_provider.dart';
import 'state/learning_profile_provider.dart';
import 'theme/app_theme.dart';
import 'services/grade_calculator.dart';
import 'data/personal_preferences.dart';
import 'data/personal_data_repository.dart';
import 'app/firebase_entry.dart';
import 'services/grade_import_service.dart';
import 'services/transcript_image_picker.dart';
import 'state/transcript_import_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GradeCalculator.loadRules();
  runApp(const FirebaseEntry());
}

class FlmApp extends StatelessWidget {
  const FlmApp({super.key, this.profile, this.storage, this.personalData});

  final PersonalPreferences? storage;
  final PersonalDataRepository? personalData;

  final LearningProfileProvider? profile;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CourseCatalog()..load()),
        ChangeNotifierProvider(
          create: (_) =>
              profile ??
              (LearningProfileProvider(
                storage: storage,
                repository: personalData,
              )..load()),
        ),
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            profile: context.read<LearningProfileProvider>(),
            storage: storage,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TranscriptProvider(storage: storage, repository: personalData)
                ..load(),
        ),
        Provider<TranscriptImagePicker>(
          create: (_) => FileTranscriptImagePicker(),
        ),
        ChangeNotifierProvider(
          create: (context) => TranscriptImportViewModel(
            picker: context.read<TranscriptImagePicker>(),
            service: () => GradeImportService(
              baseUrl: context.read<ChatProvider>().baseUrl,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Cố vấn học tập FLM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        home: const AppShell(),
        onGenerateRoute: (settings) {
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri != null && uri.pathSegments.isNotEmpty) {
            // Route: /curricula/:id -> Màn 2
            if (uri.pathSegments.first == 'curricula' &&
                uri.pathSegments.length >= 2) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) =>
                    CurriculumDetailPage(curriculumId: uri.pathSegments[1]),
              );
            }
            // Route: /courses/:code -> Màn 3
            if (uri.pathSegments.first == 'courses' &&
                uri.pathSegments.length >= 2) {
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
