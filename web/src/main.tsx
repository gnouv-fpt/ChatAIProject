import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Navigate, NavLink, Route, Routes } from 'react-router-dom';
import { ArrowUpRight, ChevronRight, LogOut, MessageSquare, ShieldCheck, UserRound } from 'lucide-react';
import { api, getAuth, setAuth } from './api';
import type { Profile } from './api';
import { ChatPage } from './features/chat/ChatPage';
import './style.css';

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
  return <div className="app-shell"><aside className="navigation"><div className="brand"><span className="brand-mark">↗</span> lộ trình<span className="brand-dot">.</span></div><span className="nav-caption">KHÔNG GIAN CỦA BẠN</span><nav><NavLink to="/chat"><MessageSquare size={18}/>Tư vấn pháp luật<ChevronRight size={15}/></NavLink><NavLink to="/tai-khoan"><UserRound size={18}/>Tài khoản</NavLink></nav><div className="sidebar-bottom"><div className="avatar">{user.username?.slice(0, 1).toUpperCase()}</div><div><strong>{user.username}</strong><small>{user.role === 'Admin' ? 'Quản trị viên' : 'Thành viên'}</small></div><button aria-label="Đăng xuất" className="icon-button" onClick={logout}><LogOut size={18}/></button></div></aside><Routes><Route path="/chat" element={<ChatPage/>}/><Route path="/tai-khoan" element={<Account user={user}/>}/><Route path="*" element={<Navigate to="/chat" replace/>}/></Routes></div>;
}
function Account({ user }: { user: Profile }) {
  const [profile, setProfile] = useState(user); const [error, setError] = useState('');
  useEffect(() => { api<Profile>('/auth/profile').then(setProfile).catch(e => setError(e.message)); }, []);
  return <main className="account"><span className="eyebrow">TÀI KHOẢN</span><h1>Thông tin của bạn</h1>{error && <p role="alert" className="error">{error}</p>}<dl><dt>Tên người dùng</dt><dd>{profile.username}</dd><dt>Email</dt><dd>{profile.email}</dd><dt>Số dư token</dt><dd>{profile.tokenBalance?.toLocaleString('vi-VN')}</dd></dl></main>;
}
createRoot(document.getElementById('root')!).render(<React.StrictMode><BrowserRouter><App/></BrowserRouter></React.StrictMode>);
