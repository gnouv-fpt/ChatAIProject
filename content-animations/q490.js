const $ = id => document.getElementById(id);
const vehicles = [
  { id: 'moto', name: 'xe mô tô', text: 'Lượt 1: xe mô tô đi trước. Bên phải xe mô tô không có xe đang đến.', duration: 1800 },
  { id: 'car', name: 'xe con', text: 'Lượt 2: sau khi mô tô qua giao lộ, xe con tiếp tục đi.', duration: 1800 },
  { id: 'truck', name: 'xe tải', text: 'Lượt 3: xe tải đi cuối sau khi nhường hai xe kia.', duration: 1800 }
];
const prefersReducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let run = 0;
function clear() {
  run++;
  document.querySelectorAll('.route,.marker,.turns button,.order li').forEach(node => node.classList.remove('active'));
  $('play').disabled = false;
  $('status').textContent = 'Chọn Phát thứ tự để bắt đầu từ xe mô tô.';
}
function wait(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
async function animate(item, token) {
  const route = $('route-' + item.id), marker = $('marker-' + item.id);
  document.querySelectorAll('.route,.marker,.turns button,.order li').forEach(node => node.classList.remove('active'));
  const startPoint = route.getPointAtLength(0);
  marker.setAttribute('transform', `translate(${startPoint.x} ${startPoint.y})`);
  route.classList.add('active'); marker.classList.add('active');
  document.querySelector(`.turns [data-vehicle="${item.id}"]`).classList.add('active');
  document.querySelectorAll('.order li')[vehicles.indexOf(item)].classList.add('active');
  $('status').textContent = item.text;
  const length = route.getTotalLength();
  if (prefersReducedMotion.matches) {
    const point = route.getPointAtLength(length);
    marker.setAttribute('transform', `translate(${point.x} ${point.y})`);
    return;
  }
  const start = performance.now();
  await new Promise(resolve => {
    function frame(now) {
      if (token !== run) { resolve(); return; }
      const progress = Math.min(1, (now - start) / item.duration);
      const point = route.getPointAtLength(length * progress);
      marker.setAttribute('transform', `translate(${point.x} ${point.y})`);
      if (progress < 1) requestAnimationFrame(frame); else resolve();
    }
    requestAnimationFrame(frame);
  });
}
$('play').onclick = async () => {
  clear(); const token = run; $('play').disabled = true;
  for (const item of vehicles) {
    if (token !== run) break;
    await animate(item, token);
    if (token === run) await wait(prefersReducedMotion.matches ? 600 : 700);
  }
  if (token === run) { $('play').disabled = false; $('status').textContent = 'Đã xem hết: mô tô → xe con → xe tải.'; }
};
$('reset').onclick = clear;
document.querySelectorAll('.turns [data-vehicle]').forEach(button => button.onclick = async () => {
  clear(); const token = run;
  await animate(vehicles.find(item => item.id === button.dataset.vehicle), token);
});
document.addEventListener('visibilitychange', () => { if (document.hidden) clear(); });
clear();
