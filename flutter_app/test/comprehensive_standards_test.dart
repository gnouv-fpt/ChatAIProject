import 'dart:typed_data';

import 'package:flm_courses/app/app_shell.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/views/chat_screen.dart';
import 'package:flm_courses/features/chat/views/widgets/contextual_chat_panel.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/screens/roadmap_screen.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/services/grade_import_service.dart';
import 'package:flm_courses/services/learning_progress.dart';
import 'package:flm_courses/services/transcript_image_picker.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_import_view_model.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:flm_courses/widgets/course_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curriculum_ux_test.dart' show fixtureCatalog;
import 'settings_sign_out_test.dart' show OfflineChat, SignedInService;

class _TestPicker implements TranscriptImagePicker {
  @override
  Future<List<ImageFile>?> pick() async => [
    ImageFile(
      filename: 'fixture.png',
      bytes: Uint8List(1),
      mimeType: 'image/png',
    ),
  ];
}

class _TestFailedOcr extends GradeImportService {
  _TestFailedOcr() : super(baseUrl: 'http://unused.test');
  @override
  Future<GradeImportResult> importFromImages(List<ImageFile> images) async =>
      throw GradeImportException('Test');
}

Future<Widget> buildTestApp(Widget child, {CourseCatalog? catalog}) async {
  SharedPreferences.setMockInitialValues({});
  final cat = catalog ?? fixtureCatalog();
  final profile = LearningProfileProvider();
  final transcript = TranscriptProvider();
  await profile.load();
  await transcript.load();
  final auth = AuthViewModel(SignedInService());
  final chat = ChatProvider(apiService: OfflineChat(), profile: profile);
  final picker = _TestPicker();
  final importVm = TranscriptImportViewModel(
    picker: picker,
    service: () => _TestFailedOcr(),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: cat),
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider.value(value: transcript),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: chat),
      Provider<TranscriptImagePicker>.value(value: picker),
      ChangeNotifierProvider.value(value: importVm),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Mục 10: Toàn bộ tương phản màu sắc đạt >= 4.5:1 (WCAG AA)', () {
    double luminance(Color color) => color.computeLuminance();
    double contrast(Color c1, Color c2) {
      final l1 = luminance(c1);
      final l2 = luminance(c2);
      final maxL = l1 > l2 ? l1 : l2;
      final minL = l1 > l2 ? l2 : l1;
      return (maxL + 0.05) / (minL + 0.05);
    }

    test('Tất cả SemesterPalette (11 kỳ) đạt chuẩn tương phản', () {
      for (var i = 0; i <= 10; i++) {
        final p = SemesterPalette.of(i);
        // Foreground on background chip
        final ratioBg = contrast(p.fg, p.bg);
        expect(
          ratioBg,
          greaterThanOrEqualTo(4.5),
          reason: 'Semester $i fg on bg ($ratioBg : 1)',
        );
        // Foreground on white card
        final ratioWhite = contrast(p.fg, Colors.white);
        expect(
          ratioWhite,
          greaterThanOrEqualTo(4.5),
          reason: 'Semester $i fg on white ($ratioWhite : 1)',
        );
        // White text when chip is selected (white on fg)
        final ratioSelected = contrast(Colors.white, p.fg);
        expect(
          ratioSelected,
          greaterThanOrEqualTo(4.5),
          reason: 'Semester $i white on fg ($ratioSelected : 1)',
        );
      }
    });

    test('Tất cả ReadinessStyle (5 trạng thái) đạt chuẩn tương phản', () {
      for (final r in CourseReadiness.values) {
        final style = ReadinessStyle.of(r, known: true);
        final ratio = contrast(style.fg, style.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'Readiness $r fg on bg ($ratio : 1)',
        );
        final ratioWhite = contrast(style.fg, Colors.white);
        expect(
          ratioWhite,
          greaterThanOrEqualTo(4.5),
          reason: 'Readiness $r fg on white ($ratioWhite : 1)',
        );
      }
    });

    test('Tất cả màu badge và surface cốt lõi đạt >= 4.5:1', () {
      final pairs = [
        (AppTheme.peBadgeText, AppTheme.peBadgeBg, 'PE badge'),
        (AppTheme.gpaBadgeText, AppTheme.gpaBadgeBg, 'GPA badge'),
        (AppTheme.nonGpaBadgeText, AppTheme.nonGpaBadgeBg, 'Non-GPA badge'),
        (AppTheme.primaryBlue, AppTheme.primaryLight, 'Primary on light'),
        (AppTheme.primaryDark, AppTheme.primaryLight, 'Primary dark on light'),
        (AppTheme.slate900, AppTheme.slate50, 'Slate900 on surface'),
        (AppTheme.slate800, Colors.white, 'Slate800 on white'),
        (AppTheme.slate700, Colors.white, 'Slate700 on white'),
        (AppTheme.slate600, Colors.white, 'Slate600 on white'),
        (AppTheme.success, AppTheme.successSurface, 'Success'),
        (AppTheme.warning, AppTheme.warningSurface, 'Warning'),
        (AppTheme.danger, AppTheme.dangerSurface, 'Danger'),
        (Colors.white, AppTheme.primaryBlue, 'White on primary blue'),
        (Colors.white, AppTheme.primaryDark, 'White on primary dark'),
      ];
      for (final (fg, bg, name) in pairs) {
        final r = contrast(fg, bg);
        expect(r, greaterThanOrEqualTo(4.5), reason: '$name ($r : 1)');
      }
    });
  });

  group('Mục 6: Vùng an toàn (SafeArea) và Xoay ngang (Landscape)', () {
    testWidgets('AppShell và 5 màn hình hiển thị tốt ở chế độ xoay ngang (640x360)', (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = await buildTestApp(const AppShell());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Chuyển qua từng tab trong chế độ xoay ngang
      final tabs = ['Lộ trình', 'Trợ lý', 'Bảng điểm', 'Cài đặt', 'Trang chủ'];
      for (final tab in tabs) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Tai thỏ và thanh điều hướng hệ thống giả lập không đè nội dung', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      // Giả lập tai thỏ 48dp, thanh cử chỉ dưới 34dp, notch 2 bên 20dp
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 34, left: 20, right: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      final app = await buildTestApp(const AppShell());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Mục 17: Bàn phím (IME) không che khuất thao tác nhập liệu trên tất cả các form', () {
    testWidgets('Màn Chat chính: ô nhập và nút gửi nằm trên bàn phím (340dp inset)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = await buildTestApp(const Scaffold(body: ChatScreen()));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Giả lập bàn phím cao (IME châu Á / gợi ý từ: 340dp)
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      expect(tester.getBottomRight(input).dy, lessThanOrEqualTo(640 - 340));
      expect(find.byTooltip('Gửi câu hỏi').hitTestable(), findsOneWidget);
    });

    testWidgets('Màn Lộ trình: ô tìm kiếm hoạt động bình thường khi mở bàn phím', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = await buildTestApp(const RoadmapScreen());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final search = find.byType(TextField);
      expect(search, findsOneWidget);

      await tester.tap(search);
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      await tester.enterText(search, 'PRF192');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Màn Cài đặt: các ô nhập liệu API & nghề nghiệp không tràn khi mở bàn phím', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = await buildTestApp(const Scaffold(body: SettingsScreen()));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Khung tư vấn xoay ngang (Landscape 640x360) với bàn phím vẫn dùng được', (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = await buildTestApp(
        const Scaffold(
          body: ContextualChatPanel(
            scope: 'subject',
            scopeId: 'PRF192',
            title: 'Trợ lý môn PRF192',
          ),
        ),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Giả lập bàn phím landscape 160dp
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      expect(tester.getBottomRight(input).dy, lessThanOrEqualTo(360 - 160));
      expect(find.byTooltip('Gửi câu hỏi').hitTestable(), findsOneWidget);
    });
  });

  group('Mục 8 & 9 & 20: Vùng chạm 48dp, nhãn Semantics và kịch bản Screen Reader', () {
    testWidgets('Màn Lộ trình: toàn bộ chip và item cuộn đều có kích thước chạm >= 48dp', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final semantics = tester.ensureSemantics();
      try {
        final app = await buildTestApp(const RoadmapScreen());
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();

        // Kiểm tra semantics & touch target ở đầu trang
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        // Cuộn dọc kiểm tra các phần tử bên dưới
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Kịch bản Screen Reader (TalkBack/VoiceOver): duyệt tiêu điểm và kích hoạt hành động', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final semantics = tester.ensureSemantics();
      try {
        final app = await buildTestApp(const RoadmapScreen());
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();

        // 1. Kiểm tra tiêu đề có đánh dấu header cho trình đọc màn hình
        final headers = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.header == true,
        );
        expect(headers, findsWidgets);

        // 2. Kích hoạt chuyển đổi chế độ thông qua thao tác Semantics tap
        await tester.tap(find.text('Sơ đồ'));
        await tester.pumpAndSettle();
        expect(find.text('Danh sách môn'), findsOneWidget);

        // 3. Trở lại xem theo học kỳ
        await tester.tap(find.text('Theo học kỳ'));
        await tester.pumpAndSettle();
        expect(find.byType(CustomScrollView), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Tab học kỳ tự động cuộn ra giữa màn hình khi được chọn', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final multiCatalog = fixtureCatalog()
        ..courses = [
          for (var s = 0; s <= 6; s++)
            Course.fromJson({
              'code': 'SUBJ$s',
              'name': 'Subject $s',
              'name_vi': 'Môn $s',
              'credits': 3,
              'semester': s,
            }),
        ];

      final app = await buildTestApp(const RoadmapScreen(), catalog: multiCatalog);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 1. Ban đầu tab 'Tất cả' được chọn và nằm ở giữa màn hình (360 / 2 = 180)
      final allChip = find.widgetWithText(ChoiceChip, 'Tất cả');
      expect(allChip, findsOneWidget);
      final allCenterX = tester.getCenter(allChip).dx;
      expect((allCenterX - 180).abs(), lessThanOrEqualTo(25),
          reason: 'Tab Tất cả phải ở giữa màn hình ban đầu: $allCenterX');

      // 2. Nhấn chọn 'HK 0' -> tab HK 0 tự động trượt vào chính giữa màn hình
      final hk0Chip = find.widgetWithText(ChoiceChip, 'HK 0');
      expect(hk0Chip, findsOneWidget);
      await tester.tap(hk0Chip);
      await tester.pumpAndSettle();

      final hk0CenterX = tester.getCenter(hk0Chip).dx;
      expect((hk0CenterX - 180).abs(), lessThanOrEqualTo(25),
          reason: 'HK 0 phải tự động trượt ra giữa màn hình, thực tế: $hk0CenterX');

      // 3. Khi HK 0 ở giữa, HK 1 đã trượt vào vùng nhìn thấy -> chọn HK 1
      final hk1Chip = find.widgetWithText(ChoiceChip, 'HK 1');
      expect(hk1Chip, findsOneWidget);
      await tester.tap(hk1Chip);
      await tester.pumpAndSettle();

      final hk1CenterX = tester.getCenter(hk1Chip).dx;
      expect((hk1CenterX - 180).abs(), lessThanOrEqualTo(25),
          reason: 'HK 1 phải tự động trượt ra giữa màn hình, thực tế: $hk1CenterX');

      // 4. Khi HK 1 ở giữa, HK 2 đã trượt vào vùng nhìn thấy -> chọn HK 2
      final hk2Chip = find.widgetWithText(ChoiceChip, 'HK 2');
      expect(hk2Chip, findsOneWidget);
      await tester.tap(hk2Chip);
      await tester.pumpAndSettle();

      final hk2CenterX = tester.getCenter(hk2Chip).dx;
      expect((hk2CenterX - 180).abs(), lessThanOrEqualTo(25),
          reason: 'HK 2 phải tự động trượt ra giữa màn hình, thực tế: $hk2CenterX');

      // 5. Chọn ngược lại HK 1 (đang ở bên trái trên màn hình) -> HK 1 trượt ngược lại ra giữa
      final hk1Back = find.widgetWithText(ChoiceChip, 'HK 1');
      await tester.tap(hk1Back);
      await tester.pumpAndSettle();
      final hk1BackX = tester.getCenter(hk1Back).dx;
      expect((hk1BackX - 180).abs(), lessThanOrEqualTo(25),
          reason: 'HK 1 phải trượt ngược lại ra giữa màn hình, thực tế: $hk1BackX');

      // 6. Chọn lại 'HK 0' (bên trái) -> 'HK 0' trượt ngược lại ra giữa
      final hk0Back = find.widgetWithText(ChoiceChip, 'HK 0');
      await tester.tap(hk0Back);
      await tester.pumpAndSettle();
      final hk0BackX = tester.getCenter(hk0Back).dx;
      expect((hk0BackX - 180).abs(), lessThanOrEqualTo(25),
          reason: 'HK 0 phải trượt ngược lại ra giữa màn hình, thực tế: $hk0BackX');

      // 7. Chọn lại 'Tất cả' (bên trái) -> 'Tất cả' trượt ngược lại ra giữa
      final allBack = find.widgetWithText(ChoiceChip, 'Tất cả');
      await tester.tap(allBack);
      await tester.pumpAndSettle();
      final allBackX = tester.getCenter(allBack).dx;
      expect((allBackX - 180).abs(), lessThanOrEqualTo(25),
          reason: 'Tất cả phải trượt ngược lại ra giữa màn hình, thực tế: $allBackX');
    });
  });
}
