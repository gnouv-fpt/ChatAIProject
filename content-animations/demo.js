const $ = id => document.getElementById(id);
const steps = [
  { x: 15, label: 'Đang chạy', caption: 'Xe đang lưu thông; người chờ ở điểm đón.' },
  { x: 160, label: 'Giảm tốc', caption: 'Người lái giảm tốc và chuẩn bị dừng tạm.' },
  { x: 290, label: 'Dừng tạm', caption: 'Xe đứng yên trong thời gian cần thiết để hành khách lên xe. Đây là ý chính của đáp án 2.', boarded: true },
  { x: 510, label: 'Tiếp tục đi', caption: 'Sau khi đón khách, xe tiếp tục di chuyển; việc đứng yên chỉ là tạm thời.', boarded: true }
];
let index = 0, timer = null;
function pause() { if (timer) clearInterval(timer); timer = null; $('play').textContent = 'Phát'; }
function render() {
  const step = steps[index];
  const travel = Math.max(0, $('road-width').offsetWidth - 130);
  $('car').style.setProperty('--car-x', `${Math.round(step.x / 510 * travel)}px`);
  $('person').classList.toggle('boarded', !!step.boarded);
  $('step-number').textContent = `Bước ${index + 1} / ${steps.length}`;
  $('step-time').textContent = step.label;
  $('caption').textContent = step.caption;
  $('previous').disabled = index === 0;
  $('next').disabled = index === steps.length - 1;
}
document.querySelector('.road').id = 'road-width';
$('previous').onclick = () => { pause(); index = Math.max(0, index - 1); render(); };
$('next').onclick = () => { pause(); index = Math.min(steps.length - 1, index + 1); render(); };
$('reset').onclick = () => { pause(); index = 0; render(); };
$('play').onclick = () => {
  if (timer) { pause(); return; }
  if (index === steps.length - 1) index = 0;
  render(); $('play').textContent = 'Tạm dừng';
  timer = setInterval(() => { if (index === steps.length - 1) { pause(); return; } index++; render(); }, 2300);
};
document.querySelectorAll('.choice').forEach(button => button.onclick = () => {
  document.querySelectorAll('.choice').forEach(choice => choice.classList.remove('selected', 'wrong'));
  const correct = button.dataset.answer === '2';
  button.classList.add(correct ? 'selected' : 'wrong');
  $('feedback').classList.toggle('wrong', !correct);
  $('feedback').textContent = correct
    ? 'Đúng. Đáp án 2 trong bản gốc mô tả xe đứng yên tạm thời, trong khoảng thời gian cần thiết và kèm điều kiện an toàn.'
    : 'Chưa đúng. Đáp án gốc là số 2: việc dừng chỉ mang tính tạm thời. Xem các bước minh họa và mở PDF để đọc toàn văn.';
  index = 0; pause(); render();
});
window.addEventListener('resize', render);
document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
render();
