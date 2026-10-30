import { validateScenario } from './scenario-contract.mjs';

const element = id => document.getElementById(id);
const previous = element('previous'), next = element('next'), play = element('play'), reset = element('reset');
let scenario = null, position = 0, timer = null;
function pause() { if (timer !== null) clearInterval(timer); timer = null; play.textContent = 'Phát'; }
function render() {
  if (!scenario) return;
  const step = scenario.steps[position];
  element('vehicle').style.transform = `translate(${step.x}px,${step.y}px) rotate(${step.rotation}deg)`;
  element('caption').textContent = step.caption;
  element('position').textContent = `${position + 1} / ${scenario.steps.length}`;
  previous.disabled = position === 0; next.disabled = position === scenario.steps.length - 1;
  play.disabled = false; reset.disabled = false;
}
function load(value) {
  pause();
  const errors = validateScenario(value);
  if (errors.length) throw new Error(errors.join(' '));
  scenario = value; position = 0;
  element('title').textContent = value.title; element('description').textContent = value.description;
  element('identity').textContent = `Câu ${value.questionId} · Bank version ${value.bankVersion}${value.isFixture ? ' · FIXTURE KIỂM THỬ' : ''}`;
  element('source').href = value.sourceUrl; element('source').hidden = false; element('error').textContent = ''; render();
}
previous.addEventListener('click', () => { pause(); if (position > 0) position--; render(); });
next.addEventListener('click', () => { pause(); if (position < scenario.steps.length - 1) position++; render(); });
reset.addEventListener('click', () => { pause(); position = 0; render(); });
play.addEventListener('click', () => {
  if (timer !== null) { pause(); return; }
  if (position === scenario.steps.length - 1) position = 0;
  render(); play.textContent = 'Tạm dừng';
  timer = setInterval(() => { if (position === scenario.steps.length - 1) { pause(); return; } position++; render(); }, 2500);
});
document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
window.addEventListener('pagehide', pause);
element('file').addEventListener('change', async event => {
  const file = event.target.files?.[0]; if (!file) return;
  try { if (file.size > 128 * 1024) throw new Error('Gói tình huống tối đa 128 KB.'); load(JSON.parse(await file.text())); }
  catch (error) { element('error').textContent = error.message; }
});
try {
  const response = await fetch('./scenario.json', { credentials: 'omit' });
  if (response.ok) { load(await response.json()); element('authoring').hidden = true; }
  else if (response.status !== 404) throw new Error('Không đọc được gói tình huống đã triển khai.');
} catch (error) { element('error').textContent = error.message; }
