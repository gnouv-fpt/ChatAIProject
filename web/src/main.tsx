import React, { useEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Navigate, NavLink, Route, Routes, useNavigate } from 'react-router-dom';
import { ArrowUpRight, ChartNoAxesColumn, ChevronRight, LogOut, MessageSquare, ShieldCheck, UserRound } from 'lucide-react';
import { api, getAuth, setAuth } from './api';
import type { Profile } from './api';
import { QuestionLibrary } from './features/questions/QuestionLibrary';
import { LegalLibrary } from './features/questions/LegalLibrary';
import { AdminContent } from './features/admin-content/AdminContent';
import { ContentPreflight } from './features/admin-content/ContentPreflight';
import type { ContentApi } from './features/questions/content-api';
import { BookOpen, ClipboardList, Settings } from 'lucide-react';
import { ChatPage } from './features/chat/ChatPage';
import { AccountPage } from './features/account/AccountPage';
import { ProgressPage } from './features/progress/ProgressPage';
import './style.css';

const contentApi: ContentApi = <T,>(path: string, init?: RequestInit) => api<T>(path.replace(/^\/api/, ''), init);
function LearningPage() {
  const navigate = useNavigate();
  return <main className="content-panel"><QuestionLibrary api={contentApi} onStartPractice={async selection => {
    if (selection.topic || selection.from || selection.to) throw new Error('Hiện đề custom lấy toàn bộ ngân hàng. Hãy xóa bộ lọc trước khi bắt đầu.');
    navigate('/thi?bank=' + encodeURIComponent(selection.bankId) + '&version=' + encodeURIComponent(selection.bankVersion) + '&count=' + selection.count);
  }}/></main>;
}
function ExamPage() {
  const frame = useRef<HTMLIFrameElement>(null);
  useEffect(() => {
    const receive = async (event: MessageEvent) => {
      if (event.origin !== location.origin || event.source !== frame.current?.contentWindow || event.data?.type !== 'exam-request') return;
      const { id, path, method, data } = event.data;
      if (typeof id !== 'string' || typeof path !== 'string' ||
          !/^\/api\/(custom-exams(?:\/|$)|exam-notifications$|question-banks$)/.test(path) ||
          !['GET', 'POST', 'PUT'].includes(method)) return;
      try {
        const body = await api(path.slice(4), { method, body: data === undefined ? undefined : JSON.stringify(data) });
        frame.current?.contentWindow?.postMessage({ type: 'exam-response', id, body }, location.origin);
      } catch (error) {
        frame.current?.contentWindow?.postMessage({ type: 'exam-response', id, error: (error as Error).message }, location.origin);
      }
    };
    window.addEventListener('message', receive);
    return () => window.removeEventListener('message', receive);
  }, []);
  return <main className="content-panel exam-panel"><iframe ref={frame} title="Luyện thi luật giao thông" src={'/exams/' + location.search}
    onLoad={() => frame.current?.contentWindow?.postMessage({ type: 'exam-ready' }, location.origin)}/></main>;
}
function App() {
  const [user, setUser] = useState<Profile | null>(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [register, setRegister] = useState(false);
  useEffect(() => { const expire = () => setUser(null); window.addEventListener('auth-expired', expire); return () => window.removeEventListener('auth-expired', expire); }, []);
  async function login(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); setBusy(true);
    const data = Object.fromEntries(new FormData(event.currentTarget));
    try {
      const result = await api<NonNullable<ReturnType<typeof getAuth>>>(register ? '/auth/register' : '/auth/login', { method: 'POST', body: JSON.stringify(data) });
      setAuth(result); setUser(result.user);
    } catch (e) { setError((e as Error).message); } finally { setBusy(false); }
  }
  async function logout() {
    try { await api('/auth/logout', { method: 'POST', body: JSON.stringify({ refreshToken: getAuth()?.refreshToken }) }); }
    catch { /* Local sign-out still clears credentials when the server is unreachable. */ }
    finally { setAuth(null); setUser(null); }
  }
  if (!user) return <main className="auth-page"><section className="auth-intro"><div className="brand"><span className="brand-mark">↗</span> lộ trình<span className="brand-dot">.</span></div><span className="eyebrow">HIỂU LUẬT · VỮNG TAY LÁI</span><h1>Mỗi hành trình,<br/>thêm một điều rõ ràng.</h1><p>Hỏi đáp luật giao thông bằng ngôn ngữ của bạn. Đối chiếu căn cứ pháp lý ngay trong mỗi câu trả lời.</p><div className="source-note"><ShieldCheck size={20}/> Trích dẫn từ Thư Viện Pháp Luật</div></section><section className="auth-form"><span className="eyebrow">CHÀO MỪNG BẠN</span><h2>{register ? 'Tạo tài khoản' : 'Tiếp tục hành trình'}</h2><p>Đăng nhập để lưu các cuộc trò chuyện của bạn.</p><form onSubmit={login}>{register && <label>Tên người dùng<input name="username" minLength={3} maxLength={50} required autoComplete="username"/></label>}<label>Email<input type="email" name="email" required autoComplete="email"/></label><label>Mật khẩu<input type="password" name="password" required minLength={register ? 8 : 1} autoComplete={register ? 'new-password' : 'current-password'}/></label>{error && <p role="alert" className="error">{error}</p>}<button className="primary" disabled={busy}>{busy ? 'Đang kết nối…' : register ? 'Tạo tài khoản' : 'Đăng nhập'}<ArrowUpRight size={18}/></button></form><button className="link-button" onClick={() => { setRegister(!register); setError(''); }}>{register ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký'}</button></section></main>;
  return <div className="app-shell"><aside className="navigation"><div className="brand"><span className="brand-mark">↗</span> lộ trình<span className="brand-dot">.</span></div><span className="nav-caption">KHÔNG GIAN CỦA BẠN</span><nav><NavLink to="/chat"><MessageSquare size={18}/>Tư vấn pháp luật<ChevronRight size={15}/></NavLink><NavLink aria-label="Học luật" to="/hoc"><BookOpen size={18}/>Học luật</NavLink><NavLink aria-label="Văn bản" to="/van-ban"><BookOpen size={18}/>Văn bản</NavLink><NavLink aria-label="Luyện thi" to="/thi"><ClipboardList size={18}/>Luyện thi</NavLink>{user.role === 'Admin' && <NavLink aria-label="Nội dung" to="/noi-dung"><Settings size={18}/>Nội dung</NavLink>}<NavLink to="/tien-do"><ChartNoAxesColumn size={18}/>Tiến độ học</NavLink><NavLink to="/tai-khoan"><UserRound size={18}/>Tài khoản</NavLink></nav><div className="sidebar-bottom"><div className="avatar">{user.username?.slice(0, 1).toUpperCase()}</div><div><strong>{user.username}</strong><small>{user.role === 'Admin' ? 'Quản trị viên' : 'Thành viên'}</small></div><button aria-label="Đăng xuất" className="icon-button" onClick={logout}><LogOut size={18}/></button></div></aside><Routes><Route path="/chat" element={<ChatPage/>}/><Route path="/hoc" element={<LearningPage/>}/><Route path="/van-ban" element={<main className="content-panel"><LegalLibrary api={contentApi}/></main>}/><Route path="/thi" element={<ExamPage/>}/><Route path="/noi-dung" element={user.role === 'Admin' ? <main className="content-panel"><ContentPreflight api={contentApi}/><AdminContent api={contentApi}/></main> : <Navigate to="/hoc" replace/>}/><Route path="/tien-do" element={<ProgressPage/>}/><Route path="/tai-khoan" element={<AccountPage user={user}/>}/><Route path="*" element={<Navigate to="/chat" replace/>}/></Routes></div>;
}
createRoot(document.getElementById('root')!).render(<React.StrictMode><BrowserRouter><App/></BrowserRouter></React.StrictMode>);
