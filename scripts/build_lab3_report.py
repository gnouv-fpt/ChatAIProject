from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output' / 'pdf' / 'PRM393_Lab3_Local_Implementation_Report_2026-11-07.pdf'

pdfmetrics.registerFont(TTFont('ArialUnicode', r'C:\Windows\Fonts\arial.ttf'))
pdfmetrics.registerFont(TTFont('ArialUnicode-Bold', r'C:\Windows\Fonts\arialbd.ttf'))

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name='CoverTitle', parent=styles['Title'], fontName='ArialUnicode', fontSize=25,
                          leading=31, textColor=colors.HexColor('#0B2E59'), alignment=TA_CENTER, spaceAfter=18))
styles.add(ParagraphStyle(name='CoverSub', parent=styles['BodyText'], fontName='ArialUnicode', fontSize=12,
                          leading=18, textColor=colors.HexColor('#3F4A59'), alignment=TA_CENTER))
styles.add(ParagraphStyle(name='H1Lab', parent=styles['Heading1'], fontName='ArialUnicode', fontSize=19,
                          leading=24, textColor=colors.HexColor('#0B2E59'), spaceAfter=10))
styles.add(ParagraphStyle(name='H2Lab', parent=styles['Heading2'], fontName='ArialUnicode', fontSize=13,
                          leading=17, textColor=colors.HexColor('#0B2E59'), spaceBefore=8, spaceAfter=5))
styles.add(ParagraphStyle(name='BodyLab', parent=styles['BodyText'], fontName='ArialUnicode', fontSize=10.2,
                          leading=14.5, textColor=colors.HexColor('#1F2937'), spaceAfter=6))
styles.add(ParagraphStyle(name='SmallLab', parent=styles['BodyText'], fontName='ArialUnicode', fontSize=8.5,
                          leading=11, textColor=colors.HexColor('#374151')))
styles.add(ParagraphStyle(name='StatusOk', parent=styles['BodyText'], fontName='ArialUnicode', fontSize=9.5,
                          leading=12, textColor=colors.HexColor('#166534')))
styles.add(ParagraphStyle(name='StatusOpen', parent=styles['BodyText'], fontName='ArialUnicode', fontSize=9.5,
                          leading=12, textColor=colors.HexColor('#9A3412')))

def p(text, style='BodyLab'):
    return Paragraph(text, styles[style])

def table(rows, widths, header=True):
    result = Table([[p(cell, 'SmallLab') for cell in row] for row in rows], colWidths=widths, repeatRows=1 if header else 0)
    commands = [
        ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#CBD5E1')),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 7), ('RIGHTPADDING', (0, 0), (-1, -1), 7),
        ('TOPPADDING', (0, 0), (-1, -1), 6), ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]
    if header:
        commands += [('BACKGROUND', (0,0), (-1,0), colors.HexColor('#0B2E59')),
                     ('TEXTCOLOR', (0,0), (-1,0), colors.white)]
    for r in range(1 if header else 0, len(rows)):
        if r % 2 == 0:
            commands.append(('BACKGROUND', (0,r), (-1,r), colors.HexColor('#F8FAFC')))
    result.setStyle(TableStyle(commands))
    return result

def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor('#CBD5E1'))
    canvas.line(1.8*cm, 1.45*cm, A4[0]-1.8*cm, 1.45*cm)
    canvas.setFont('ArialUnicode', 8)
    canvas.setFillColor(colors.HexColor('#64748B'))
    canvas.drawString(1.8*cm, 0.95*cm, 'PRM393 Lab 3 - local implementation evidence')
    canvas.drawRightString(A4[0]-1.8*cm, 0.95*cm, f'Page {doc.page}')
    canvas.restoreState()

story = []
story += [Spacer(1, 4.2*cm), p('PRM393 Lab 3', 'CoverTitle'), p('Cloud Enabled Mobile App', 'CoverTitle'),
          Spacer(1, 0.7*cm), p('Báo cáo hiện thực cục bộ và kiểm chứng kỹ thuật', 'CoverSub'),
          Spacer(1, 0.5*cm), p('Dự án: FLM Student Assistant<br/>Ngày rà soát: 07/11/2026<br/>Phạm vi: Firebase, ARTEMIS preparation, AI code review và chất lượng Flutter', 'CoverSub'),
          Spacer(1, 2.2*cm), p('Tuyên bố phạm vi', 'H2Lab'),
          p('Báo cáo này phân biệt rõ evidence đã chạy local với evidence cần Firebase Console hoặc thiết bị Android thật. Không có mục nào bên dưới tuyên bố deploy, publish, push hoặc chạy production khi chưa có bằng chứng tương ứng.'), PageBreak()]

story += [p('1. Tóm tắt kiểm chứng', 'H1Lab'),
          p('Ứng dụng Flutter đã có source integration cho sáu dịch vụ Firebase: Authentication, Cloud Storage, Cloud Messaging, Analytics, Crashlytics và Remote Config. Ranh giới service và Provider giữ Firebase SDK ngoài widget.'),
          table([
              ['Hạng mục', 'Evidence local đã xác minh', 'Trạng thái'],
              ['Flutter quality', 'flutter analyze không có issue; flutter test --exclude-tags live: 238/238 pass', 'Đạt local'],
              ['Firebase rules', 'Firestore và Storage emulator: 14/14 pass', 'Đạt local'],
              ['ARTEMIS preparation', '10-case catalogue có validator: 3/3 checks pass', 'Đạt preparation'],
              ['Android build', 'flutter build apk --debug tạo app-debug.apk', 'Đạt build'],
              ['Console and device evidence', 'Chưa chạy trong báo cáo này', 'Còn mở'],
          ], [3.2*cm, 8.2*cm, 3.0*cm]), Spacer(1, 0.7*cm),
          p('Bản build debug được tạo tại flutter_app/build/app/outputs/flutter-apk/app-debug.apk. Các test production-like hoặc live bị loại khỏi full suite theo tag live, nên kết quả 238/238 không thay thế smoke test Firebase thật.'), PageBreak()]

story += [p('2. Firebase Authentication', 'H1Lab'),
          p('Luồng đã có AuthGate, FirebaseAuthService, Google sign-in, trạng thái loading/signed out/signed in/error và sign out theo UID. Cache cá nhân được namespace theo account/{uid}; sign out khóa ghi và không xóa dữ liệu tài khoản khác.'),
          p('Error handling', 'H2Lab'),
          p('Hủy đăng nhập và lỗi provider được đưa về thông báo có thể hiểu. Nếu sign out thất bại, cache của account hiện tại mở lại để người dùng thử lại thay vì mất dữ liệu cục bộ.'),
          p('Evidence local', 'H2Lab'),
          table([['Case', 'Kết quả'], ['Auth gate signed out', 'Kiểm widget tại 360dp và 412dp pass'], ['Account isolation', '5 test bảo vệ namespace, stale write và sign-out failure pass'], ['Review trace', 'CR01 và CR02 đã accept/fix trong docs/code-review.md']], [4.1*cm, 10.3*cm]),
          p('Evidence còn thiếu', 'H2Lab'), p('Google login native thật, cancel và logout trên Android; ảnh Authentication Users trong Firebase Console.'), PageBreak()]

story += [p('3. Cloud Storage và Security Rules', 'H1Lab'),
          p('ReportService tạo PDF từ dữ liệu đang xem, upload vào reports/{uid}/..., phát progress và URL. Firestore report metadata và Storage object đều kiểm owner, MIME application/pdf, ownerUid metadata, filename timestamp và giới hạn 10 MiB.'),
          p('Rules posture', 'H2Lab'), p('Rules default-deny. Người không đăng nhập và account khác không được đọc hoặc ghi object/report của owner. Schema metadata bị giới hạn trường và kích thước.'),
          table([['Emulator suite', 'Phạm vi'], ['Firestore', 'profile, preferences, transcript, role, notifications và report metadata'], ['Storage', 'owner upload/read/delete; cross-account deny; MIME/path/metadata/size reject'], ['Kết quả', '14/14 pass với Firebase emulators']], [3.7*cm, 10.7*cm]),
          p('Evidence còn thiếu', 'H2Lab'), p('Upload PDF thật, UI progress và URL cuối cùng trên Android; object và rules trong Storage Console; kiểm tra mất mạng.'), PageBreak()]

story += [p('4. Cloud Messaging', 'H1Lab'),
          p('PushService xin quyền notification Android 13+, quản lý token, xử lý foreground, background và terminated message, lưu notification history theo owner và điều hướng destination an toàn. Cloud Hub hiển thị lịch sử thông báo.'),
          p('Kiểm tra có trong source', 'H2Lab'),
          table([['State', 'Hành vi source'], ['Foreground', 'Nhận message, lưu history, hiển thị theo luồng app'], ['Background', 'Background handler cố lưu khi còn session'], ['Terminated', 'Initial message được đọc để điều hướng sau launch'], ['Permission denied', 'UI/permission state có nhánh từ chối']], [3.7*cm, 10.7*cm]),
          p('Evidence còn thiếu', 'H2Lab'), p('Gửi test notification từ Firebase Console cho cả ba trạng thái, token thật, ảnh device và bằng chứng chạm thông báo dẫn đúng destination.'), PageBreak()]

story += [p('5. Analytics và Crashlytics', 'H1Lab'),
          p('FirebaseAppTelemetry dùng allowlist event và parameter. Kế hoạch analytics liệt kê login, logout, search, view_course, view_curriculum, transcript_import, transcript_import_error, advising_request, export_report, upload_report và notification_open.'),
          p('Privacy controls', 'H2Lab'), p('Không gửi tên, email, ảnh, điểm, search term hoặc chat tự do. Search dùng query_length thay vì nội dung query. UID được đặt sau sign-in và reset ở sign-out.'),
          p('Crashlytics', 'H2Lab'), p('Khởi tạo Crashlytics trong bootstrap; các nonfatal error, user identifier và diagnostic key có service wrapper. Khu vực demo crash được tách khỏi luồng sử dụng thường ngày.'),
          p('Evidence còn thiếu', 'H2Lab'), p('Analytics DebugView cho từng event, một nonfatal và một crash test trong Crashlytics Console cùng user ID/key. Không coi config source là evidence Console.'), PageBreak()]

story += [p('6. Remote Config', 'H1Lab'),
          p('FeatureConfig tách Remote Config khỏi widget. Template firebase/remoteconfig.template.json có hai tham số hành vi: home_show_daily_tip và home_recommendation_limit. Home screen dùng chúng để đổi nội dung gợi ý và giới hạn kết quả mà không cần build mới.'),
          table([['Yêu cầu', 'Hiện thực local', 'Evidence còn thiếu'], ['Tối thiểu hai parameter', '2 parameter trong template và default local', 'Ảnh Console'], ['Thay đổi quan sát được', 'Daily tip và recommendation limit ảnh hưởng Home', 'Before/after publish'], ['Offline fallback', 'Default local còn khi fetch/activate lỗi', 'Device network-off demo']], [3.1*cm, 5.3*cm, 5.8*cm]),
          Spacer(1, 0.5*cm), p('Kết luận phần này: source chứng minh mapping từ parameter tới hành vi; chỉ Console publish và device before/after mới chứng minh được remote delivery.'), PageBreak()]

story += [p('7. ARTEMIS preparation', 'H1Lab'),
          p('Thư mục e2e_test chứa catalogue 10 ca, assertions evidence và validator. Các ca phủ luồng Lab 2, một nhánh lỗi và native Android interaction theo guide.'),
          table([['Nhóm', 'Ví dụ coverage'], ['Sign-in and account', 'gate, Google cancel/error và sign-out'], ['Curriculum and advising', 'search course, contextual advisor, prerequisite context'], ['Transcript', 'OCR empty/error recovery, manual entry, persistence'], ['Cloud features', 'report upload surface, notification center, Remote Config fallback']], [3.6*cm, 10.8*cm]),
          p('Kết quả hiện có', 'H2Lab'), p('pytest e2e_test/test_checks.py -q: 3/3 passed. Đây xác minh cấu trúc catalogue và evidence checks, không phải 30 lần chạy ARTEMIS trên device.'),
          p('Evidence còn thiếu', 'H2Lab'), p('Mỗi ca chạy 3 lần trên Android, ghi actual observation, thiết bị/OS, pass rate và phiên exploratory 15-30 phút.'), PageBreak()]

story += [p('8. AI Code Review', 'H1Lab'),
          p('docs/code-review.md lưu local review trace trên diff PRM-dev với sáu finding mới. Review không được mô tả là output của Copilot, CodeRabbit hoặc PR remote.'),
          table([['ID', 'Nhóm', 'Quyết định'], ['CR-L3-01', 'Error handling', 'Telemetry best-effort không chặn sign-out'], ['CR-L3-02', 'Reliability', 'Hủy upload progress listener'], ['CR-L3-03', 'Architecture', 'Remote Config đổi hành vi Home'], ['CR-L3-04', 'Data consistency', 'Lưu notification nền trong giới hạn platform'], ['CR-L3-05', 'Security', 'Harden ownership/schema/MIME/size'], ['CR-L3-06', 'Privacy', 'Analytics allowlist không nhận free text']], [2.5*cm, 3.3*cm, 8.6*cm]),
          p('Traceability', 'H2Lab'), p('Các fix liên quan có commit local, gồm e9a99f5 cho Firebase workflows và 12146cf/d5bf9eb/00569c4/42b7d0c cho reliability, accessibility và regression tests. PR/push chưa thực hiện.'), PageBreak()]

story += [p('9. Build và regression verification', 'H1Lab'),
          table([['Command', 'Kết quả'], ['flutter analyze', 'No issues found'], ['flutter test --exclude-tags live --concurrency=1', '238/238 passed'], ['flutter build apk --debug', 'Built app-debug.apk'], ['Firebase emulators:exec', '14/14 rules tests passed'], ['pytest e2e_test/test_checks.py -q', '3/3 passed']], [7.1*cm, 7.3*cm]),
          Spacer(1, 0.7*cm), p('Accessibility work verified in regression suite includes 48dp touch targets, large-text behavior, contextual chat controls, transcript save reachability and recovery actions when Settings profile load fails.'),
          p('Tool warnings', 'H2Lab'), p('JDK and plugin compatibility warnings during Android debug build are toolchain migration warnings. The build exits successfully. The Storage Rules emulator prints a shutdown NPE after successful tests; test process exits code 0 and all 14 tests pass.'), PageBreak()]

story += [p('10. Readiness and remaining evidence', 'H1Lab'),
          p('Local code, automated tests and debug APK are ready for a supervised evidence pass. The following must be captured before presenting the Lab as fully completed.'),
          table([['Required evidence', 'How to close'], ['Authentication', 'Real Android Google sign-in, cancellation, logout, Authentication Users Console'], ['Storage', 'Generated PDF upload, progress, URL, object and unauthorized access evidence'], ['FCM', 'Console test message in foreground/background/terminated plus tap routing'], ['Analytics', 'DebugView screenshots covering selected events'], ['Crashlytics', 'Console nonfatal and intentional demo crash with diagnostic context'], ['Remote Config', 'Console publish then before/after behavior without rebuild'], ['ARTEMIS', '10 cases x 3 runs and 15-30 min exploratory log'], ['Submission packaging', 'Report PDF, 12-15 slide PDF and 5-10 minute demo video']], [4.2*cm, 10.2*cm]),
          Spacer(1, 0.7*cm), p('This report supplies the report-PDF portion only. It does not manufacture Console screenshots, device runs or a video recording.'), PageBreak()]

story += [p('11. Reproduction checklist', 'H1Lab'),
          p('1. Install the debug APK on an Android 13+ emulator or device.<br/>2. Configure the Firebase project and confirm Google sign-in SHA/authorized domains.<br/>3. Capture each required Console/device observation while executing the matching scenario.<br/>4. Attach logs and screenshots to the evidence folder with date, device, app build and case ID.<br/>5. Re-run the commands below after any source change.'),
          p('Local commands', 'H2Lab'),
          table([['Purpose', 'Command'], ['Flutter checks', 'flutter analyze; flutter test --exclude-tags live --concurrency=1'], ['APK', 'flutter build apk --debug'], ['Rules', 'firebase emulators:exec --only firestore,storage --project demo-flm-lab3 --config firebase.json "npm --prefix firebase test"'], ['ARTEMIS catalogue', '.venv\\Scripts\\python.exe -m pytest e2e_test\\test_checks.py -q']], [4.5*cm, 9.9*cm]),
          Spacer(1, 0.7*cm), p('Final status', 'H2Lab'), p('The local implementation and regression checks are complete. Firebase Console deployment/publish, real-device execution, remote pull request/push, and the required recording remain external actions and are intentionally left unclaimed in this report.')]

OUT.parent.mkdir(parents=True, exist_ok=True)
doc = SimpleDocTemplate(str(OUT), pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm, topMargin=1.7*cm, bottomMargin=1.8*cm)
doc.build(story, onFirstPage=footer, onLaterPages=footer)
print(OUT)
