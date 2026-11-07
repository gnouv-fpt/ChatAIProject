import fs from 'node:fs/promises';
import path from 'node:path';
import {Presentation, PresentationFile} from '@oai/artifact-tool';

const root = path.resolve(import.meta.dirname, '..');
const buildDir = path.join(root, 'tmp', 'lab3-deck-build');
const outDir = path.join(root, 'output', 'slides');
const candidate = path.join(buildDir, 'PRM393_Lab3_Evidence_Deck.draft.pptx');

async function writeBlob(file, blob) {
  await fs.writeFile(file, new Uint8Array(await blob.arrayBuffer()));
}
function textbox(slide, text, left, top, width, height, style = {}) {
  const s = slide.shapes.add({geometry: 'textbox', position: {left, top, width, height}, fill: 'none', line: {style: 'solid', fill: 'none', width: 0}});
  s.text = text;
  s.text.style = {fontFamily: 'Arial', fontSize: 20, color: '1F2937', ...style};
  return s;
}
function line(slide, left, top, width, color = 'CBD5E1') {
  slide.shapes.add({geometry: 'rect', position: {left, top, width, height: 2}, fill: color, line: {style: 'solid', fill: color, width: 0}});
}
function footer(slide, page) {
  line(slide, 72, 665, 1136);
  textbox(slide, 'FLM Student Assistant  •  PRM393 Lab 3', 72, 680, 440, 20, {fontSize: 11, color: '64748B'});
  textbox(slide, String(page).padStart(2, '0'), 1150, 680, 58, 20, {fontSize: 11, color: '64748B', align: 'right'});
}
function header(slide, page, title, kicker = 'LAB 3 EVIDENCE DECK') {
  textbox(slide, kicker, 72, 42, 450, 22, {fontSize: 12, bold: true, color: '2563EB'});
  textbox(slide, title, 72, 84, 1080, 54, {fontSize: 33, bold: true, color: '0B2E59'});
  line(slide, 72, 152, 1136, '93C5FD');
  footer(slide, page);
}
function bulletList(slide, items, left, top, width, size = 20) {
  let y = top;
  for (const item of items) {
    textbox(slide, '•', left, y, 20, 28, {fontSize: size, color: '2563EB'});
    textbox(slide, item, left + 30, y, width - 30, 48, {fontSize: size, color: '1F2937'});
    y += 63;
  }
}
function evidenceNote(slide, text, page) {
  textbox(slide, text, 72, 600, 1136, 34, {fontSize: 13, color: '9A3412', italic: true});
}

await fs.mkdir(buildDir, {recursive: true});
await fs.mkdir(outDir, {recursive: true});
const deck = Presentation.create({slideSize: {width: 1280, height: 720}});

{ const s = deck.slides.add();
  s.background.fill = 'F8FAFC';
  textbox(s, 'PRM393 Lab 3', 72, 120, 900, 70, {fontSize: 48, bold: true, color: '0B2E59'});
  textbox(s, 'FLM Student Assistant', 72, 200, 900, 58, {fontSize: 38, color: '2563EB'});
  textbox(s, 'Báo cáo hiện thực cục bộ và evidence cần xác minh trên Firebase Console / Android', 72, 292, 900, 64, {fontSize: 22, color: '475569'});
  line(s, 72, 410, 240, '2563EB');
  textbox(s, 'Ngày rà soát: 07/11/2026', 72, 438, 500, 30, {fontSize: 17, color: '475569'});
  textbox(s, 'Không tuyên bố deploy, publish hoặc device result nếu chưa có evidence thật.', 72, 505, 980, 34, {fontSize: 16, color: '9A3412'});
  footer(s, 1);
}
{ const s = deck.slides.add(); header(s, 2, 'Phạm vi và ranh giới kiến trúc');
  textbox(s, 'View', 100, 260, 170, 52, {fontSize: 26, bold: true, color: '0B2E59', align:'center'});
  textbox(s, 'Provider', 360, 260, 200, 52, {fontSize: 26, bold: true, color: '0B2E59', align:'center'});
  textbox(s, 'Service', 665, 260, 190, 52, {fontSize: 26, bold: true, color: '0B2E59', align:'center'});
  textbox(s, 'Firebase SDK', 970, 260, 210, 52, {fontSize: 26, bold: true, color: '0B2E59', align:'center'});
  line(s, 285, 286, 55, '2563EB'); line(s, 580, 286, 55, '2563EB'); line(s, 875, 286, 55, '2563EB');
  bulletList(s, ['Sáu service: Authentication, Storage, Messaging, Analytics, Crashlytics, Remote Config.', 'Widget không gọi trực tiếp Firebase SDK.', 'Trạng thái loading, data, empty và error nằm ở Provider/ViewModel.'], 100, 390, 1040, 19);
}
{ const s = deck.slides.add(); header(s, 3, 'Firebase Authentication');
  bulletList(s, ['AuthGate điều hướng signed out đến SignInScreen và signed in đến app shell.', 'Cache profile, transcript và chat được namespace theo UID.', 'Sign out thất bại giữ cache cho retry, không xóa account khác.'], 84, 205, 1010, 22);
  evidenceNote(s, 'Cần chèn trước nộp: Google sign-in/cancel/logout trên Android và Authentication Users Console.', 3);
}
{ const s = deck.slides.add(); header(s, 4, 'Cloud Storage và report PDF');
  bulletList(s, ['ReportService tạo PDF từ dữ liệu hiện tại và upload reports/{uid}/....', 'UI có progress, retry và download URL.', 'Storage Rules kiểm owner, MIME application/pdf, metadata, filename và 10 MiB.'], 84, 205, 1010, 22);
  evidenceNote(s, 'Cần chèn trước nộp: upload UI, URL cuối, Storage Console object và unauthorized deny.', 4);
}
{ const s = deck.slides.add(); header(s, 5, 'Firebase Cloud Messaging');
  bulletList(s, ['PushService xin permission Android 13+ và quản lý token.', 'Foreground, background và terminated message có handler riêng.', 'Notification history theo owner và notification tap điều hướng destination an toàn.'], 84, 205, 1010, 22);
  evidenceNote(s, 'Cần chèn trước nộp: ba trạng thái notification thật và permission-denied trên device.', 5);
}
{ const s = deck.slides.add(); header(s, 6, 'Analytics và privacy');
  bulletList(s, ['Allowlist gồm login/logout, course view, transcript, advising, export/upload report và notification open.', 'Không log email, tên, ảnh, điểm, search text hoặc chat free text.', 'search chỉ log query_length và result_count.'], 84, 205, 1010, 22);
  evidenceNote(s, 'Cần chèn trước nộp: Firebase Analytics DebugView cho các event trình diễn.', 6);
}
{ const s = deck.slides.add(); header(s, 7, 'Crashlytics');
  bulletList(s, ['Bootstrap Crashlytics trong Firebase entry.', 'Service wrapper gửi nonfatal, user identifier và diagnostic key.', 'Intentional crash chỉ ở khu demo, không nằm trong luồng bình thường.'], 84, 205, 1010, 22);
  evidenceNote(s, 'Cần chèn trước nộp: Console evidence của nonfatal, intentional crash, user/key.', 7);
}
{ const s = deck.slides.add(); header(s, 8, 'Remote Config');
  bulletList(s, ['Template định nghĩa enable_pe_tips và next_course_preview_limit.', 'FeatureConfig fetch/activate ngoài widget.', 'Hai parameter đổi hành vi Home; default local dùng khi mất mạng.'], 84, 205, 1010, 22);
  evidenceNote(s, 'Cần chèn trước nộp: Console publish và before/after app behavior không build lại.', 8);
}
{ const s = deck.slides.add(); header(s, 9, 'Firebase Security Rules');
  textbox(s, '14/14 emulator tests passed', 72, 205, 550, 54, {fontSize: 32, bold: true, color: '166534'});
  bulletList(s, ['Firestore và Storage mặc định deny.', 'Owner-only access và schema validation cho profile, transcript, notification, report.', 'Negative tests kiểm cross-account, anonymous, wrong MIME/path/metadata/size.'], 84, 300, 1010, 20);
  textbox(s, 'Kết quả local, không thay thế production Console evidence.', 84, 570, 860, 26, {fontSize: 15, color: '475569'});
}
{ const s = deck.slides.add(); header(s, 10, 'ARTEMIS preparation');
  textbox(s, '10 test cases', 90, 220, 340, 45, {fontSize: 30, bold: true, color:'0B2E59'});
  textbox(s, '3/3 catalogue validator checks', 90, 290, 570, 45, {fontSize: 26, color:'166534'});
  bulletList(s, ['Coverage: sign-in, curriculum/advising, transcript, cloud feature surfaces.', 'Rubric còn yêu cầu mỗi ca chạy 3 lần trên Android và exploratory session 15-30 phút.'], 84, 390, 1040, 20);
  evidenceNote(s, 'Cần chèn trước nộp: actual observation table 30 runs, device/OS và exploratory log.', 10);
}
{ const s = deck.slides.add(); header(s, 11, 'AI Code Review và commit trace');
  bulletList(s, ['Six findings thuộc error handling, reliability, architecture, data consistency, security và privacy.', 'Accepted fixes: best-effort telemetry, upload listener cancellation, Remote Config behavior, rules hardening, analytics allowlist.', 'Trace documented in docs/code-review.md; review là local Codex review, không giả mạo PR remote review.'], 84, 205, 1040, 20);
  textbox(s, 'Recent local commits: e9a99f5, 12146cf, d5bf9eb, 00569c4, 42b7d0c.', 84, 545, 1050, 28, {fontSize: 15, color:'475569'});
}
{ const s = deck.slides.add(); header(s, 12, 'Verification và việc còn mở');
  textbox(s, '238/238 Flutter tests   •   14/14 Rules tests   •   Debug APK built', 72, 205, 1100, 42, {fontSize: 25, bold:true, color:'166534'});
  bulletList(s, ['Đã có report PDF, recording script và slide plan local.', 'Cần deploy/publish Firebase và chạy Android thật để đóng Google login, FCM, DebugView, Crashlytics, Remote Config, ARTEMIS và video evidence.', 'Branch PRM-dev chưa push.'], 84, 300, 1040, 20);
  textbox(s, 'Kết luận: source và local checks sẵn sàng cho evidence pass có giám sát.', 84, 560, 1050, 30, {fontSize: 17, color:'0B2E59'});
}

await (await PresentationFile.exportPptx(deck)).save(candidate);
for (const [i, slide] of deck.slides.items.entries()) {
  await writeBlob(path.join(buildDir, `slide-${String(i+1).padStart(2, '0')}.png`), await deck.export({slide, format:'png', scale:1}));
}
console.log(candidate);
