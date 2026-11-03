const $ = id => document.getElementById(id);
const vehicles = [
  { id: 'moto', text: 'Lượt 1: xe mô tô đi trước.', duration: 4500 },
  { id: 'car', text: 'Lượt 2: xe con đi sau mô tô.', duration: 4500 },
  { id: 'truck', text: 'Lượt 3: xe tải đi cuối.', duration: 4500 }
];
let run = 0;
let paused = false;
let activeItem = vehicles[0];

function updateProgress(progress) {
  const percent = Math.round(progress * 100);
  $('progress').value = percent;
  $('progress-value').textContent = `${percent}%`;
}

function reset() {
  run++;
  paused = false;
  activeItem = vehicles[0];
  document.querySelectorAll('.route,.turns button,.order li').forEach(node => node.classList.remove('active'));
  document.querySelectorAll('.vehicle').forEach(node => {
    node.classList.remove('gone');
    node.removeAttribute('transform');
  });
  $('vehicle-truck').querySelector('image').removeAttribute('mask');
  $('play').disabled = false;
  $('pause').disabled = true;
  $('pause').textContent = 'Tạm dừng';
  updateProgress(0);
  $('status').textContent = 'Chọn Phát thứ tự để bắt đầu từ xe mô tô.';
}

function positionOnRoute(route, vehicle, progress) {
  const length = route.getTotalLength();
  const start = route.getPointAtLength(0);
  const point = route.getPointAtLength(length * progress);
  const near = route.getPointAtLength(Math.min(length, length * progress + 2));
  const before = route.getPointAtLength(Math.max(0, length * progress - 2));
  const startDirection = route.getPointAtLength(2);
  const angle = Math.atan2(near.y - before.y, near.x - before.x)
    - Math.atan2(startDirection.y - start.y, startDirection.x - start.x);
  vehicle.setAttribute('transform', `translate(${point.x - start.x} ${point.y - start.y}) rotate(${angle * 180 / Math.PI} ${start.x} ${start.y})`);
}

async function animate(item, token) {
  activeItem = item;
  const route = $('route-' + item.id);
  const vehicle = $('vehicle-' + item.id);
  if (item.id === 'truck') vehicle.querySelector('image').setAttribute('mask', 'url(#truck-moving-mask)');
  document.querySelectorAll('.route,.turns button,.order li').forEach(node => node.classList.remove('active'));
  route.classList.add('active');
  document.querySelector(`.turns [data-vehicle="${item.id}"]`).classList.add('active');
  document.querySelectorAll('.order li')[vehicles.indexOf(item)].classList.add('active');
  $('status').textContent = item.text;
  $('pause').disabled = false;
  updateProgress(0);
  // Playback only starts after an explicit click; the slider also supports motion-free inspection.
  let elapsed = 0;
  let previous = performance.now();
  await new Promise(resolve => {
    function frame(now) {
      if (token !== run) { resolve(); return; }
      if (!paused) elapsed += Math.min(now - previous, 100);
      previous = now;
      const progress = Math.min(1, elapsed / item.duration);
      positionOnRoute(route, vehicle, progress);
      updateProgress(progress);
      if (progress < 1) requestAnimationFrame(frame);
      else { $('pause').disabled = true; resolve(); }
    }
    requestAnimationFrame(frame);
  });
}

function wait(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

$('play').onclick = async () => {
  reset();
  document.querySelector('.stage').scrollIntoView({ block: 'start', behavior: 'instant' });
  const token = run;
  $('play').disabled = true;
  for (const item of vehicles) {
    if (token !== run) break;
    await animate(item, token);
    if (token === run) await wait(900);
  }
  if (token === run) {
    $('play').disabled = false;
    $('status').textContent = 'Đã xem hết: mô tô → xe con → xe tải.';
  }
};

$('reset').onclick = reset;
$('pause').onclick = () => {
  paused = !paused;
  $('pause').textContent = paused ? 'Tiếp tục' : 'Tạm dừng';
};
$('progress').oninput = () => {
  run++;
  paused = false;
  $('play').disabled = false;
  $('pause').disabled = true;
  $('pause').textContent = 'Tạm dừng';
  const progress = Number($('progress').value) / 100;
  positionOnRoute($('route-' + activeItem.id), $('vehicle-' + activeItem.id), progress);
  $('route-' + activeItem.id).classList.add('active');
  updateProgress(progress);
  $('status').textContent = `${activeItem.text} Vị trí ${Math.round(progress * 100)}%.`;
};
document.querySelectorAll('.turns [data-vehicle]').forEach(button => button.onclick = async () => {
  reset();
  document.querySelector('.stage').scrollIntoView({ block: 'start', behavior: 'instant' });
  await animate(vehicles.find(item => item.id === button.dataset.vehicle), run);
});
document.addEventListener('visibilitychange', () => { if (document.hidden) reset(); });
reset();
