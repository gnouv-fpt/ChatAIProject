import { useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { QuestionLibrary } from './features/questions/QuestionLibrary';
import { AdminContent } from './features/admin-content/AdminContent';
import { LegalLibrary } from './features/questions/LegalLibrary';
import { createContentApi } from './features/questions/content-api';
import './content.css';

// Preview host only. V04 shell should import feature components and inject its authenticated API client.
function ContentPreview() {
  const [token, setToken] = useState(''); const [draft, setDraft] = useState(''); const [view, setView] = useState('questions');
  const api = useMemo(() => createContentApi(token), [token]);
  return <main><header><strong>Giao thông · Nội dung học</strong>{token && <button onClick={() => { setToken(''); setDraft(''); }}>Xóa phiên xem trước</button>}</header>
    {!token ? <form onSubmit={e => { e.preventDefault(); setToken(draft.trim()); setDraft(''); }}><h1>Xem trước module nội dung</h1>
      <p>Dùng access token từ Auth API. Token chỉ giữ trong bộ nhớ của tab.</p><label>Access token<input type="password" required value={draft} onChange={e => setDraft(e.target.value)}/></label><button>Kết nối API</button></form> :
      <><nav><button onClick={() => setView('questions')}>Câu hỏi</button><button onClick={() => setView('laws')}>Văn bản luật</button><button onClick={() => setView('admin')}>Quản trị nội dung</button></nav>
      {view === 'admin' ? <AdminContent api={api}/> : view === 'laws' ? <LegalLibrary api={api}/> : <QuestionLibrary api={api}/>}</>}
  </main>;
}
createRoot(document.getElementById('root')!).render(<ContentPreview/>);
