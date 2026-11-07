import {readFile} from 'node:fs/promises';
import {after, before, test} from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {ref, uploadBytes, getBytes, deleteObject} from 'firebase/storage';

let env;
const [host,portText]=(process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199').split(':');
before(async () => {
  env = await initializeTestEnvironment({
    projectId:'demo-flm-lab3',
    storage:{host,port:Number(portText),rules:await readFile(new URL('../storage.rules',import.meta.url),'utf8')},
  });
});
after(async () => { if (env) await env.cleanup(); });
const storage = uid => uid ? env.authenticatedContext(uid).storage() : env.unauthenticatedContext().storage();
const pdf = new Uint8Array([0x25,0x50,0x44,0x46,0x2d,0x31,0x2e,0x37]);

test('owner can upload/read/delete a scoped PDF', async () => {
  const file=ref(storage('owner'),'reports/owner/1234567890123.pdf');
  await assertSucceeds(uploadBytes(file,pdf,{contentType:'application/pdf',customMetadata:{ownerUid:'owner'}}));
  await assertSucceeds(getBytes(file));
  await assertSucceeds(deleteObject(file));
});

test('anonymous and another user cannot access a report', async () => {
  const ownerFile=ref(storage('owner'),'reports/owner/1234567890124.pdf');
  await assertSucceeds(uploadBytes(ownerFile,pdf,{contentType:'application/pdf',customMetadata:{ownerUid:'owner'}}));
  await assertFails(getBytes(ref(storage('other'),'reports/owner/1234567890124.pdf')));
  await assertFails(getBytes(ref(storage(null),'reports/owner/1234567890124.pdf')));
});

test('uploads reject wrong type, metadata, path and oversized bytes', async () => {
  await assertFails(uploadBytes(ref(storage('owner'),'reports/owner/1234567890125.pdf'),pdf,
    {contentType:'text/plain',customMetadata:{ownerUid:'owner'}}));
  await assertFails(uploadBytes(ref(storage('owner'),'reports/owner/1234567890126.pdf'),pdf,
    {contentType:'application/pdf',customMetadata:{ownerUid:'other'}}));
  await assertFails(uploadBytes(ref(storage('owner'),'reports/other/1234567890127.pdf'),pdf,
    {contentType:'application/pdf',customMetadata:{ownerUid:'owner'}}));
  await assertFails(uploadBytes(ref(storage('owner'),'reports/owner/not-a-valid-name.pdf'),pdf,
    {contentType:'application/pdf',customMetadata:{ownerUid:'owner'}}));
  const oversized=new Uint8Array(10*1024*1024+1);
  await assertFails(uploadBytes(ref(storage('owner'),'reports/owner/1234567890128.pdf'),oversized,
    {contentType:'application/pdf',customMetadata:{ownerUid:'owner'}}));
});
