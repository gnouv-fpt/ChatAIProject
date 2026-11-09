import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/chat/providers/chat_provider.dart';
import 'app/app_shell.dart';
import 'models/transcript_entry.dart';
import 'pages/course_detail_page.dart';
import 'pages/curriculum_detail_page.dart';
import 'state/course_catalog.dart';
import 'state/transcript_provider.dart';
import 'state/learning_profile_provider.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';
import 'services/grade_calculator.dart';
import 'data/personal_preferences.dart';
import 'data/personal_data_repository.dart';
import 'app/firebase_entry.dart';
import 'services/grade_import_service.dart';
import 'services/transcript_image_picker.dart';
import 'state/transcript_import_view_model.dart';
import 'widgets/config_error_screen.dart';
import 'services/app_telemetry.dart';
import 'screens/cloud_hub_screen.dart';
import 'widgets/notification_route_listener.dart';

String? validateReleaseConfig() {
  const configured = String.fromEnvironment('FLM_API_BASE_URL');
  if (kReleaseMode && configured.isEmpty) {
    return 'Thiếu biến môi trường: FLM_API_BASE_URL\n'
        'Lệnh biên dịch: flutter build ... --dart-define=FLM_API_BASE_URL=https://<api-host>';
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configError = validateReleaseConfig();
  if (configError != null) {
    runApp(ConfigErrorApp(message: configError, onRetry: () => main()));
    return;
  }
  await GradeCalculator.loadRules();
  runApp(const FirebaseEntry());
}

class FlmApp extends StatelessWidget {
  const FlmApp({
    super.key,
    this.profile,
    this.storage,
    this.personalData,
    this.telemetry,
  });

  final PersonalPreferences? storage;
  final PersonalDataRepository? personalData;

  final LearningProfileProvider? profile;
  final AppTelemetry? telemetry;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppTelemetry?>.value(value: telemetry),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
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
            telemetry: telemetry,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final tp = TranscriptProvider(
              storage: storage,
              repository: personalData,
            );
            if (kIsWeb && Uri.base.queryParameters['demo'] == 'populated') {
              tp.load().then((_) {
                if (!tp.hasTranscript) {
                  tp.save([
                    TranscriptEntry(
                      courseCode: 'PRF192',
                      courseName: 'Cơ sở lập trình',
                      score: 8.5,
                      credits: 3,
                      semester: 1,
                      isPassed: true,
                    ),
                    TranscriptEntry(
                      courseCode: 'MAE101',
                      courseName: 'Toán cho ngành kỹ thuật',
                      score: 7.0,
                      credits: 3,
                      semester: 1,
                      isPassed: true,
                    ),
                    TranscriptEntry(
                      courseCode: 'CEA201',
                      courseName: 'Kiến trúc máy tính',
                      score: 8.0,
                      credits: 3,
                      semester: 1,
                      isPassed: true,
                    ),
                    TranscriptEntry(
                      courseCode: 'CSI106',
                      courseName: 'Giới thiệu về Khoa học máy tính',
                      score: 6.5,
                      credits: 3,
                      semester: 1,
                      isPassed: true,
                    ),
                    TranscriptEntry(
                      courseCode: 'PRO192',
                      courseName: 'Lập trình hướng đối tượng với Java',
                      score: 0.0,
                      credits: 3,
                      semester: 2,
                      isPassed: false,
                      inProgress: true,
                    ),
                    TranscriptEntry(
                      courseCode: 'MAD101',
                      courseName: 'Toán rời rạc',
                      score: 0.0,
                      credits: 3,
                      semester: 2,
                      isPassed: false,
                      inProgress: true,
                    ),
                  ]);
                  tp.setTargetGpa(8.2);
                }
              });
            } else {
              tp.load();
            }
            return tp;
          },
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
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final effectiveMode =
              (kIsWeb && Uri.base.queryParameters['theme'] == 'dark')
              ? ThemeMode.dark
              : (kIsWeb && Uri.base.queryParameters['theme'] == 'light')
              ? ThemeMode.light
              : themeProvider.themeMode;
          return MaterialApp(
            title: 'Cố vấn học tập FLM',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: effectiveMode,
            home: const NotificationRouteListener(child: AppShell()),
            routes: {'/cloud-hub': (_) => const CloudHubScreen()},
            onGenerateRoute: (settings) {
              final uri = Uri.tryParse(settings.name ?? '');
              if (uri != null && uri.pathSegments.isNotEmpty) {
                // Route: /curricula/:id -> Màn 2
                if (uri.pathSegments.first == 'curricula' &&
                    uri.pathSegments.length >= 2) {
                  unawaited(
                    telemetry?.event('view_curriculum', {
                      'curriculum_id': uri.pathSegments[1],
                    }),
                  );
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) =>
                        CurriculumDetailPage(curriculumId: uri.pathSegments[1]),
                  );
                }
                // Route: /courses/:code -> Màn 3
                if (uri.pathSegments.first == 'courses' &&
                    uri.pathSegments.length >= 2) {
                  unawaited(
                    telemetry?.event('view_course', {
                      'course_code': uri.pathSegments[1],
                      'entry_point': 'named_route',
                    }),
                  );
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => CourseDetailPage(code: uri.pathSegments[1]),
                  );
                }
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
