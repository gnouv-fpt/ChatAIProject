import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { parseBankFile, reviewedImportBody } from '../web/src/features/admin-content/content-import.ts';

test('reviewed 600 question packages preserve all questions, 115 animation URLs and source metadata', async () => {
  for (const folder of ['csgt-2025-https', 'csgt-2025-B-current']) {
    const text = await readFile(new URL(`../content-bank/${folder}/package.json`, import.meta.url), 'utf8');
    const original = JSON.parse(text);
    const parsed = parseBankFile(text);
    assert.deepEqual(parsed.manifest.bank, original.bank);
    assert.equal(parsed.manifest.bank.questions.length, 600);
    assert.equal(parsed.manifest.bank.questions.filter(q => q.explanationAnimationUrl).length, 115);
    assert.deepEqual(parsed.manifest.animations, []);
    assert.equal(parsed.templateCount, original.templates.length);
    assert.deepEqual(reviewedImportBody(parsed.manifest, 'a'.repeat(64)).bank, original.bank);
  }
});

test('raw banks and mapping manifests work without mutating or dropping animation IDs', () => {
  const bank = { id: 'bank', questions: [{ id: 'q1' }] };
  assert.deepEqual(parseBankFile(JSON.stringify(bank)), { manifest: { bank, animations: [] }, templateCount: 0 });
  const manifest = { bank, animations: [{ questionId: 'q1', explanationAnimationUrl: 'https://example.org/q1.html' }] };
  const parsed = parseBankFile(JSON.stringify(manifest));
  assert.deepEqual(parsed.manifest, manifest);
  assert.deepEqual(reviewedImportBody(parsed.manifest, 'B'.repeat(64)), { ...manifest, expectedManifestHash: 'B'.repeat(64) });
  assert.deepEqual(parsed.manifest, manifest);
});

test('malformed files and unreviewed imports are rejected', () => {
  for (const text of ['{', 'null', '[]', 'true', '{"bank":null}', '{"bank":{},"animations":null}', '{"bank":{},"animations":{}}'])
    assert.throws(() => parseBankFile(text), Error, text);
  const manifest = { bank: {}, animations: [] };
  assert.throws(() => reviewedImportBody(manifest, null));
  assert.throws(() => reviewedImportBody(manifest, 'wrong-hash'));
});
