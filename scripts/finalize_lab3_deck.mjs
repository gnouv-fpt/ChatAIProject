import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';

const root = path.resolve(import.meta.dirname, '..');
const skill = 'C:\\Users\\LEGION\\.codex\\plugins\\cache\\openai-primary-runtime\\presentations\\26.1105.12137\\skills\\presentations';
const runtimePython = 'C:\\Users\\LEGION\\.cache\\codex-runtimes\\codex-primary-runtime\\dependencies\\python\\python.exe';
const candidate = path.join(root, 'tmp', 'lab3-deck-build', 'PRM393_Lab3_Evidence_Deck.draft.pptx');
const finalPath = path.join(root, 'output', 'slides', 'PRM393_Lab3_Evidence_Deck_2026-11-07.pptx');
const {finalizePresentation} = await import(pathToFileURL(path.join(skill, 'container_tools', 'artifact_tool_utils.mjs')).href);
await fs.mkdir(path.dirname(finalPath), {recursive:true});
await fs.mkdir(path.join(root, 'tmp', 'lab3-deck-finalizer'), {recursive:true});
const result = await finalizePresentation({
  explicitTotalSlideCount: 12,
  workspaceDir: root,
  candidatePath: candidate,
  finalPath,
  pythonExecutable: runtimePython,
  integrityValidatorPath: path.join(skill, 'container_tools', 'inspect_presentation_package_integrity.py'),
  layoutValidatorPath: path.join(skill, 'container_tools', 'inspect_presentation_layout_geometry.py'),
  layoutArgs: ['--expected-slide-size-emu', '12192000,6858000', '--validate-heading-fit'],
  requiredNativeTableOwnerSlides: [],
  fontPolicy: {basis:'design', families:['Arial']},
  verifyArtifactToolImport: true,
  receiptPath: path.join(root, 'tmp', 'lab3-deck-finalizer', 'validation.json'),
});
console.log(JSON.stringify(result));
