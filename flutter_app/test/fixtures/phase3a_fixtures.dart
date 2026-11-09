import 'package:flutter/material.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/models/transcript_entry.dart';
import 'package:flm_courses/services/auth_service.dart';
import 'package:flm_courses/services/grade_import_service.dart';
import 'package:flm_courses/services/transcript_image_picker.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_import_view_model.dart';
import 'package:flm_courses/state/theme_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:provider/provider.dart';

class MockImagePicker implements TranscriptImagePicker {
  @override
  Future<List<ImageFile>?> pick() async => null;
}

class TestAuthService implements AuthService {
  TestAuthService({
    this.userName = 'Nguyễn Đăng Khôi',
    this.userEmail = 'khoind@fpt.edu.vn',
    this.signedIn = true,
  });
  final String userName;
  final String userEmail;
  final bool signedIn;

  @override
  Stream<AuthAccount?> get changes => Stream.value(
        signedIn ? AuthAccount(uid: 'khoind', name: userName, email: userEmail) : null,
      );

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signOut() async {}
}

class OfflineChatService extends ChatApiService {
  @override
  Future<bool> checkHealth() async => false;
}

List<TranscriptEntry> createSampleTranscriptEntries() {
  return [
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
      courseCode: 'CSI104',
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
  ];
}

Widget wrapWithTestProviders({
  required Widget child,
  required CourseCatalog catalog,
  required LearningProfileProvider profile,
  required TranscriptProvider transcript,
  required AuthViewModel auth,
  required ChatProvider chat,
  bool isDark = false,
  double textScale = 1.0,
  Size viewport = const Size(390, 844),
  Key? repaintKey,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider(initialMode: isDark ? ThemeMode.dark : ThemeMode.light)),
      ChangeNotifierProvider.value(value: catalog),
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider.value(value: transcript),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: chat),
      Provider<TranscriptImagePicker>(create: (_) => MockImagePicker()),
      ChangeNotifierProvider(
        create: (context) => TranscriptImportViewModel(
          picker: context.read<TranscriptImagePicker>(),
          service: () => GradeImportService(baseUrl: chat.baseUrl),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: SizedBox(
          width: viewport.width,
          height: viewport.height,
          child: repaintKey != null
              ? RepaintBoundary(key: repaintKey, child: child)
              : child,
        ),
      ),
    ),
  );
}
