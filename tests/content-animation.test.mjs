import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { validateScenario } from '../content-animations/scenario-contract.mjs';
import { isAllowedAnimationUrl } from '../web/src/features/questions/animation-url.ts';

const fixture = JSON.parse(await readFile(new URL('../content-animations/scenario.example.json', import.meta.url), 'utf8'));
test('fixture is explicitly marked and validates', () => { assert.equal(fixture.isFixture, true); assert.deepEqual(validateScenario(fixture), []); });
test('source and question/version are required', () => {
  assert.ok(validateScenario({ ...fixture, sourceUrl: 'javascript:alert(1)' }).length);
  assert.ok(validateScenario({ ...fixture, questionId: '' }).length);
  assert.ok(validateScenario({ ...fixture, bankVersion: '../latest' }).length);
});
test('coordinates and captions are bounded', () => {
  assert.ok(validateScenario({ ...fixture, steps: [{ caption: 'test', x: Infinity, y: 20, rotation: 0 }, fixture.steps[0]] }).length);
  assert.ok(validateScenario({ ...fixture, steps: [{ ...fixture.steps[0], caption: '' }, fixture.steps[1]] }).length);
  assert.ok(validateScenario({ ...fixture, steps: [null, fixture.steps[0]] }).length);
});
test('review links only use an exact configured HTTPS host without answer/query payload', () => {
  const hosts = ['animations.example.org'];
  assert.equal(isAllowedAnimationUrl('https://animations.example.org/lesson.html', hosts), true);
  assert.equal(isAllowedAnimationUrl('https://animations.example.org/lesson/', hosts), true);
  for (const url of ['javascript:alert(1)', 'http://animations.example.org/lesson.html',
    'https://animations.example.org.evil.org/lesson.html', 'https://animations.example.org/lesson.html?key=a',
    'https://animations.example.org/lesson.html#key=a', 'https://user:pass@animations.example.org/lesson.html',
    'https://animations.example.org/../lesson.html', 'https://animations.example.org/%252e%252e/lesson.html',
    'https://animations.example.org:8443/lesson.html']) assert.equal(isAllowedAnimationUrl(url, hosts), false, url);
  assert.equal(isAllowedAnimationUrl('https://animations.example.org/lesson.html', []), false);
});
