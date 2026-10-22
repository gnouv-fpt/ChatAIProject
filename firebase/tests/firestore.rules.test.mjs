import {readFile} from 'node:fs/promises';
import {after, before, test} from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,deleteDoc,collection,getDocs,Timestamp} from 'firebase/firestore';
let env;
const [host,portText]=(process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8185').split(':');
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-flm-lab3',firestore:{host,port:Number(portText),
    rules:await readFile(new URL('../firestore.rules',import.meta.url),'utf8')}});
});
after(async () => { if (env) await env.cleanup(); });
const db = uid => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const row = {courseCode:'PRO192',courseName:'Programming',score:8,credits:3,semester:1,
  isPassed:true,inProgress:false,confidence:1};
test('owner can create/read/update/delete study profile',async () => {
  const ref=doc(db('profile-owner'),'users/profile-owner/private/profile');
  await assertSucceeds(setDoc(ref,{course_goal:'pass'}));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(setDoc(ref,{course_goal:'high_score',current_semester:2}));
  await assertSucceeds(deleteDoc(ref));
});
test('other account and signed out cannot access profile',async () => {
  for(const uid of ['other',null]) {
    const ref=doc(db(uid),'users/profile-owner/private/profile');
    await assertFails(getDoc(ref)); await assertFails(setDoc(ref,{course_goal:'pass'}));
    await assertFails(deleteDoc(ref));
  }
});
test('profile rejects extra fields, invalid enums and invalid update',async () => {
  const ref=doc(db('schema'),'users/schema/private/profile');
  await assertFails(setDoc(ref,{role:'admin'}));
  await assertFails(setDoc(ref,{course_goal:'invented'}));
  await assertFails(setDoc(ref,{current_semester:13}));
  await assertSucceeds(setDoc(ref,{course_goal:'pass'}));
  await assertFails(setDoc(ref,{career_goal:'x'.repeat(81)}));
});
test('owner can save/query/delete transcript attempts',async () => {
  const database=db('grades'); const ref=doc(database,'users/grades/transcript/PRO192_1');
  await assertSucceeds(setDoc(ref,row)); await assertSucceeds(getDoc(ref));
  await assertSucceeds(getDocs(collection(database,'users/grades/transcript')));
  await assertSucceeds(setDoc(ref,{...row,score:9})); await assertSucceeds(deleteDoc(ref));
});
test('transcript denies cross-account reads, queries and writes',async () => {
  for(const uid of ['other',null]) {
    const database=db(uid); const ref=doc(database,'users/grades/transcript/PRO192_1');
    await assertFails(getDoc(ref)); await assertFails(setDoc(ref,row));
    await assertFails(getDocs(collection(database,'users/grades/transcript')));
    await assertFails(deleteDoc(ref));
  }
});
test('transcript validates create/update, fields, numeric bounds and id',async () => {
  const ref=doc(db('invalid'),'users/invalid/transcript/PRO192_1');
  await assertFails(setDoc(ref,{...row,score:11}));
  await assertFails(setDoc(ref,{...row,credits:-1}));
  await assertFails(setDoc(ref,{...row,semester:13}));
  await assertFails(setDoc(ref,{...row,owner:'another'}));
  await assertFails(setDoc(doc(db('invalid'),'users/invalid/transcript/wrong-id'),row));
  await assertSucceeds(setDoc(ref,row));
  await assertFails(setDoc(ref,{courseCode:'PRO192'}));
});
test('GPA preferences validate type/range and ownership',async () => {
  const ref=doc(db('gpa'),'users/gpa/private/preferences');
  await assertSucceeds(setDoc(ref,{targetGpa:8.5})); await assertSucceeds(getDoc(ref));
  await assertFails(setDoc(ref,{targetGpa:11}));
  await assertFails(setDoc(ref,{targetGpa:'8'}));
  await assertFails(setDoc(doc(db('other'),'users/gpa/private/preferences'),{targetGpa:8}));
  await assertFails(getDoc(doc(db(null),'users/gpa/private/preferences')));
});
test('user cannot create or promote an admin role',async () => {
  const ref=doc(db('role'),'users/role');
  await assertFails(setDoc(ref,{role:'admin',createdAt:Timestamp.now()}));
  await assertSucceeds(setDoc(ref,{role:'user',createdAt:Timestamp.now()}));
  await assertFails(setDoc(ref,{role:'admin',createdAt:Timestamp.now()}));
  await assertFails(setDoc(doc(db('other'),'users/role'),{role:'user',createdAt:Timestamp.now()}));
});
test('unrecognized collections denied even when authenticated',async () => {
  const ref=doc(db('owner'),'unrecognized/item');
  await assertFails(getDoc(ref)); await assertFails(setDoc(ref,{value:1}));
});
