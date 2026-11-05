import {
  cpSync,
  existsSync,
  mkdirSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const output = resolve(root, 'public');

if (dirname(output) !== root || basename(output) !== 'public') {
  throw new Error(`Refusing to replace unexpected output directory: ${output}`);
}

const copy = (relativePath, outputPath = relativePath) => {
  const source = resolve(root, relativePath);
  const destination = resolve(output, outputPath);
  if (!source.startsWith(`${root}\\`) && !source.startsWith(`${root}/`)) {
    throw new Error(`Source escapes the animation project: ${relativePath}`);
  }
  if (!existsSync(source)) {
    throw new Error(`Required public asset is missing: ${relativePath}`);
  }
  mkdirSync(dirname(destination), { recursive: true });
  cpSync(source, destination, { recursive: true });
};

rmSync(output, { recursive: true, force: true });
mkdirSync(output, { recursive: true });

for (const file of [
  'learn-icon.svg',
  'q490-detailed-models.js',
]) {
  copy(file);
}
copy('asset-index.html', 'index.html');

for (let number = 486; number <= 600; number += 1) {
  copy(`bank-review/${number}/image-1.jpeg`);
}

for (const entry of readdirSync(root, { withFileTypes: true })) {
  if (!entry.isFile()) continue;
  if (!/^review-.*\.(?:js|mjs)$/.test(entry.name)) continue;
  if (entry.name === 'review-state.mjs') continue;
  copy(entry.name);
}

for (const directory of [
  'clean-plates',
  'models',
  'question-bank-600',
  'vendor',
]) {
  copy(directory);
}

writeFileSync(resolve(output, 'vercel.json'), `${JSON.stringify({
  $schema: 'https://openapi.vercel.sh/vercel.json',
  framework: null,
  buildCommand: null,
  installCommand: null,
  outputDirectory: '.',
  cleanUrls: false,
  headers: [{
    source: '/(.*)',
    headers: [
      { key: 'Access-Control-Allow-Origin', value: '*' },
      { key: 'X-Content-Type-Options', value: 'nosniff' },
    ],
  }],
  redirects: [
    { source: '/review.html', destination: '/index.html', permanent: false },
    { source: '/learn.html', destination: '/index.html', permanent: false },
  ],
}, null, 2)}\n`);

for (const forbidden of [
  'learn.html',
  'review.html',
  'review.js',
  'review-state.mjs',
  'bank-review/review-feedback.json',
  'bank-review/bank.json',
  'bank-review/scenes.json',
]) {
  if (existsSync(resolve(output, forbidden))) {
    throw new Error(`Private answer file leaked into public output: ${forbidden}`);
  }
}

const learnerPages = readdirSync(output).filter((name) => /^q[0-9]+\.html$/.test(name));
if (learnerPages.length !== 0) {
  throw new Error(`Public output must not contain learner pages; found ${learnerPages.length}.`);
}

console.log('Prepared answer-free animation asset output.');
