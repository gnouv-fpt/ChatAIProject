import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Link, Navigate, NavLink, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import {
  ArrowUpRight,
  BookOpen,
  ChartNoAxesColumn,
  Clapperboard,
  ClipboardList,
  Eye,
  EyeOff,
  FileText,
  LogOut,
  Menu,
  MessageSquare,
  Play,
  Search,
  Settings,
  ShieldCheck,
  UserRound,
  X,
} from 'lucide-react';
import { api, getAuth, setAuth } from './api';
import type { Profile } from './api';
import { QuestionLibrary } from './features/questions/QuestionLibrary';
import { LegalLibrary } from './features/questions/LegalLibrary';
import { AdminContent } from './features/admin-content/AdminContent';
import { AdminAnimationReview } from './features/admin-content/AdminAnimationReview';
import { ContentPreflight } from './features/admin-content/ContentPreflight';
import type { ContentApi } from './features/questions/content-api';
import { ChatPage } from './features/chat/ChatPage';
import { AccountPage } from './features/account/AccountPage';
import { ProgressPage } from './features/progress/ProgressPage';
import { ExamPage } from './features/exams/ExamPage';
import { ExamReviewPage } from './features/exams/ExamReviewPage';
import { Modal } from './components/Modal';
import './app.css';
import { TrafficScene } from './components/TrafficScene';

const contentApi: ContentApi = <T,>(path: string, init?: RequestInit) => api<T>(path.replace(/^\/api/, ''), init);

function LearningPage() {
  const navigate = useNavigate();
  return (
    <main className="content-panel">
      <QuestionLibrary
        api={contentApi}
        onStartPractice={async selection => {
          if (selection.topic || selection.from || selection.to) {
            throw new Error('Hiện đề custom lấy toàn bộ ngân hàng. Hãy xóa bộ lọc trước khi bắt đầu.');
          }
          navigate(
            '/thi?bank=' +
              encodeURIComponent(selection.bankId) +
              '&version=' +
              encodeURIComponent(selection.bankVersion) +
              '&count=' +
              selection.count
          );
        }}
      />
    </main>
  );
}

function DashboardTopbar({ user }: { user: Profile }) {
  const navigate = useNavigate();
  const [quickQuery, setQuickQuery] = useState('');

  function handleQuickSearch(e: React.FormEvent) {
    e.preventDefault();
    const q = quickQuery.trim();
    navigate(q ? '/van-ban?q=' + encodeURIComponent(q) : '/van-ban');
  }

  const hasQuota = typeof user.tokenBalance === 'number';

  return (
    <header className="dash-topbar" aria-label="Thanh công cụ">
      <Link to="/hoc" className="dash-mobile-brand" aria-label="Lộ trình – trang chủ">
        <span className="brand-mark">↗</span>
        <span>lộ trình<span className="brand-dot">.</span></span>
      </Link>

      <form className="dash-search-box" role="search" onSubmit={handleQuickSearch}>
        <Search size={16} className="dash-search-icon" aria-hidden="true" />
        <input
          type="search"
          value={quickQuery}
          onChange={e => setQuickQuery(e.target.value)}
          placeholder="Tìm văn bản luật, nghị định, số hiệu…"
          aria-label="Tìm văn bản pháp luật"
        />
      </form>

      <div className="dash-topbar-actions">
        <Link to="/thi" className="dash-cta-pill">
          <Play size={14} />
          <span>Làm đề nhanh</span>
        </Link>

        {hasQuota && (
          <Link to="/tai-khoan" className="dash-quota" title="Hạn mức hỏi đáp AI còn lại">
            <span className="dash-quota-label">AI</span>
            <span className="dash-quota-num">{(user.tokenBalance / 1000).toFixed(1)}k</span>
          </Link>
        )}

        <Link to="/tai-khoan" className="dash-user-chip" aria-label="Tài khoản">
          <span className="dash-user-avatar">{user.username?.slice(0, 1).toUpperCase()}</span>
          <span className="dash-user-meta desktop-only">
            <strong>{user.username}</strong>
            <small>{user.role === 'Admin' ? 'Quản trị viên' : 'Học viên'}</small>
          </span>
        </Link>
      </div>
    </header>
  );
}

function App() {
  const [user, setUser] = useState<Profile | null>(() => {
    if (typeof window !== 'undefined') {
      const saved = window.localStorage.getItem('csgt_preview_user');
      if (saved) {
        try {
          return JSON.parse(saved);
        } catch {}
      }
    }
    return null;
  });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [register, setRegister] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const expire = () => setUser(null);
    window.addEventListener('auth-expired', expire);
    return () => window.removeEventListener('auth-expired', expire);
  }, []);

  async function login(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    setBusy(true);
    const data = Object.fromEntries(new FormData(event.currentTarget));
    try {
      const result = await api<NonNullable<ReturnType<typeof getAuth>>>(
        register ? '/auth/register' : '/auth/login',
        {
          method: 'POST',
          body: JSON.stringify(data),
        }
      );
      setAuth(result);
      setUser(result.user);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function logout() {
    setMobileMenuOpen(false);
    try {
      await api('/auth/logout', {
        method: 'POST',
        body: JSON.stringify({ refreshToken: getAuth()?.refreshToken }),
      });
    } catch {
      /* Local sign-out still clears credentials when the server is unreachable. */
    } finally {
      window.localStorage.removeItem('csgt_preview_user');
      setAuth(null);
      setUser(null);
    }
  }

  if (!user) {
    return (
      <main className="login-page">
        <section className="login-hero" aria-label="Giới thiệu Lộ trình">
          <div className="login-brand">
            <span className="brand-mark">↗</span> lộ trình<span className="brand-dot">.</span>
          </div>

          <div className="login-copy">
            <h1>
              Hiểu luật hôm nay.
              <br />
              <em>Vững lái ngày mai.</em>
            </h1>
            <p>
              Ôn câu hỏi sát hạch, làm bài thi thử và xem tình huống qua mô phỏng 3D. Mỗi câu trả lời đều kèm căn cứ
              pháp lý.
            </p>
          </div>

          <div className="login-scene">
            <TrafficScene variant="compact" />
          </div>

          <ul className="login-features">
            <li>
              <BookOpen size={18} aria-hidden="true" />
              <span>
                <strong>Học luật</strong> theo chủ đề, lưu câu khó
              </span>
            </li>
            <li>
              <ClipboardList size={18} aria-hidden="true" />
              <span>
                <strong>Thi thử</strong> chấm điểm tự động
              </span>
            </li>
            <li>
              <MessageSquare size={18} aria-hidden="true" />
              <span>
                <strong>Hỏi đáp AI</strong> trích dẫn Điều, Khoản
              </span>
            </li>
          </ul>
        </section>

        <section className="login-panel">
          <div className="login-card">
            <h2>{register ? 'Tạo tài khoản' : 'Đăng nhập'}</h2>
            <p className="login-lead">
              {register
                ? 'Tạo tài khoản để lưu tiến độ ôn tập và kết quả thi thử.'
                : 'Tiếp tục ôn tập, thi thử và hỏi đáp pháp luật.'}
            </p>
            <form className="login-form" onSubmit={login} aria-busy={busy}>
              {register && (
                <label>
                  Tên người dùng
                  <input disabled={busy} name="username" minLength={3} maxLength={50} required autoComplete="username" />
                </label>
              )}
              <label>
                Email
                <input
                  disabled={busy}
                  autoCapitalize="none"
                  spellCheck={false}
                  type="email"
                  name="email"
                  required
                  autoComplete="email"
                />
              </label>
              <label>
                Mật khẩu
                <span className="password-field">
                  <input
                    disabled={busy}
                    type={showPassword ? 'text' : 'password'}
                    name="password"
                    required
                    minLength={register ? 8 : 1}
                    autoComplete={register ? 'new-password' : 'current-password'}
                  />
                  <button
                    type="button"
                    className="icon-button password-toggle"
                    aria-label={showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
                    aria-pressed={showPassword}
                    onClick={() => setShowPassword(value => !value)}
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </span>
                {register && <small className="muted">Sử dụng ít nhất 8 ký tự.</small>}
              </label>
              {error && (
                <p role="alert" className="error">
                  {error}
                </p>
              )}
              <button className="primary" disabled={busy}>
                {busy ? 'Đang kết nối…' : register ? 'Tạo tài khoản' : 'Đăng nhập'}
                <ArrowUpRight size={18} />
              </button>
            </form>
            <p className="login-switch">
              {register ? 'Đã có tài khoản?' : 'Chưa có tài khoản?'}{' '}
              <button
                type="button"
                className="link-button"
                disabled={busy}
                onClick={() => {
                  setRegister(!register);
                  setShowPassword(false);
                  setError('');
                }}
              >
                {register ? 'Đăng nhập' : 'Đăng ký'}
              </button>
            </p>

            <div className="login-divider" role="separator">
              <span>hoặc</span>
            </div>

            <button
              type="button"
              className="btn-secondary login-demo"
              onClick={() => {
                const demo: Profile = {
                  id: 'demo',
                  username: 'demo',
                  email: 'demo@example.com',
                  role: 'Admin',
                  tokenBalance: 48500,
                  tokenQuota: 100000,
                };
                window.localStorage.setItem('csgt_preview_user', JSON.stringify(demo));
                setUser(demo);
              }}
            >
              Xem thử giao diện (demo)
            </button>
          </div>

          <p className="login-footnote">
            <ShieldCheck size={15} aria-hidden="true" /> Nguồn trích dẫn: Thư Viện Pháp Luật và bộ câu hỏi sát hạch.
          </p>
        </section>
      </main>
    );
  }

  return (
    <div className="app-shell">
      {/* Desktop Left Sidebar */}
      <aside className="navigation" aria-label="Điều hướng chính">
        <div className="brand">
          <span className="brand-mark">↗</span> lộ trình<span className="brand-dot">.</span>
        </div>
        <div className="brand-subtitle">
          Học luật &amp; thi sát hạch
        </div>

        <span className="nav-caption">HÀNH TRÌNH HỌC &amp; THI</span>
        <nav>
          <NavLink aria-label="Học luật" to="/hoc">
            <BookOpen size={18} />
            <span>Học luật</span>
          </NavLink>
          <NavLink aria-label="Luyện thi" to="/thi">
            <ClipboardList size={18} />
            <span>Thi thử</span>
          </NavLink>
          <NavLink to="/tien-do">
            <ChartNoAxesColumn size={18} />
            <span>Tiến độ</span>
          </NavLink>
        </nav>

        <span className="nav-caption">TRA CỨU &amp; TÀI KHOẢN</span>
        <nav>
          <NavLink to="/chat">
            <MessageSquare size={18} />
            <span>Hỏi đáp pháp luật</span>
          </NavLink>
          <NavLink aria-label="Văn bản" to="/van-ban">
            <FileText size={18} />
            <span>Văn bản</span>
          </NavLink>
          <NavLink to="/tai-khoan">
            <UserRound size={18} />
            <span>Tài khoản</span>
          </NavLink>
        </nav>

        {user.role === 'Admin' && (
          <div className="nav-admin-box">
            <span className="nav-caption" style={{ marginTop: 0 }}>
              KHU VỰC QUẢN TRỊ
            </span>
            <nav>
              <NavLink aria-label="Nội dung" to="/noi-dung">
                <Settings size={18} />
                <span>Quản trị nội dung</span>
              </NavLink>
              <NavLink aria-label="Duyệt mô phỏng" to="/duyet-mo-phong">
                <Clapperboard size={18} />
                <span>Duyệt mô phỏng</span>
              </NavLink>
            </nav>
          </div>
        )}

        <div className="sidebar-bottom">
          <div className="avatar">{user.username?.slice(0, 1).toUpperCase()}</div>
          <div>
            <strong>{user.username}</strong>
            <small>{user.role === 'Admin' ? 'Quản trị viên' : 'Thành viên'}</small>
          </div>
          <button aria-label="Đăng xuất" className="icon-button" onClick={() => void logout()}>
            <LogOut size={18} />
          </button>
        </div>
      </aside>

      {/* Main Dashboard Stage (Topbar + Scrollable Workspace) */}
      <div className="dashboard-stage">
        <DashboardTopbar user={user} />

        <div className="dash-body">
          <Routes>
            <Route path="/chat" element={<ChatPage />} />
            <Route path="/hoc" element={<LearningPage />} />
            <Route
              path="/van-ban"
              element={
                <main className="content-panel">
                  <LegalLibrary api={contentApi} />
                </main>
              }
            />
            <Route path="/thi" element={<ExamPage />} />
            <Route path="/ket-qua/:attemptId" element={<ExamReviewPage />} />
            <Route
              path="/noi-dung"
              element={
                user.role === 'Admin' ? (
                  <main className="content-panel">
                    <AdminContent api={contentApi} />
                    <ContentPreflight api={contentApi} />
                  </main>
                ) : (
                  <Navigate to="/hoc" replace />
                )
              }
            />
            <Route
              path="/duyet-mo-phong"
              element={user.role === 'Admin' ? <AdminAnimationReview /> : <Navigate to="/hoc" replace />}
            />
            <Route path="/tien-do" element={<ProgressPage />} />
            <Route path="/tai-khoan" element={<AccountPage user={user} />} />
            <Route path="*" element={<Navigate to="/chat" replace />} />
          </Routes>
        </div>
      </div>

      {/* Mobile Bottom Navigation: 4 Priority Items + Menu */}
      <nav className="mobile-bottom-nav" aria-label="Điều hướng di động">
        <NavLink to="/chat" onClick={() => setMobileMenuOpen(false)}>
          <MessageSquare size={19} />
          <span>Hỏi đáp</span>
        </NavLink>
        <NavLink to="/hoc" onClick={() => setMobileMenuOpen(false)}>
          <BookOpen size={19} />
          <span>Học luật</span>
        </NavLink>
        <NavLink to="/thi" onClick={() => setMobileMenuOpen(false)}>
          <ClipboardList size={19} />
          <span>Thi thử</span>
        </NavLink>
        <NavLink to="/tien-do" onClick={() => setMobileMenuOpen(false)}>
          <ChartNoAxesColumn size={19} />
          <span>Tiến độ</span>
        </NavLink>
        <button
          type="button"
          className={mobileMenuOpen ? 'active' : ''}
          aria-expanded={mobileMenuOpen}
          aria-label="Mở menu mở rộng"
          onClick={() => setMobileMenuOpen(open => !open)}
        >
          {mobileMenuOpen ? <X size={19} /> : <Menu size={19} />}
          <span>Menu</span>
        </button>
      </nav>

      {/* Mobile Expandable Menu Drawer */}
      {mobileMenuOpen && (
        <Modal
          className="mobile-menu-overlay"
          label="Menu tài khoản và tra cứu"
          onClose={() => setMobileMenuOpen(false)}
        >
          <div className="mobile-menu-sheet" onClick={e => e.stopPropagation()}>
            <div className="mobile-menu-sheet-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div className="avatar">{user.username?.slice(0, 1).toUpperCase()}</div>
                <div>
                  <strong style={{ display: 'block', fontSize: '14px' }}>{user.username}</strong>
                  <small className="muted">{user.role === 'Admin' ? 'Quản trị viên' : 'Thành viên'}</small>
                </div>
              </div>
              <button
                type="button"
                className="icon-button"
                aria-label="Đóng menu"
                onClick={() => setMobileMenuOpen(false)}
              >
                <X size={18} />
              </button>
            </div>

            <div className="mobile-menu-links">
              <NavLink to="/van-ban" onClick={() => setMobileMenuOpen(false)}>
                <FileText size={18} /> Văn bản pháp luật
              </NavLink>
              <NavLink to="/tai-khoan" onClick={() => setMobileMenuOpen(false)}>
                <UserRound size={18} /> Tài khoản &amp; Hạn mức
              </NavLink>
              {user.role === 'Admin' && (
                <>
                  <NavLink to="/noi-dung" onClick={() => setMobileMenuOpen(false)}>
                    <Settings size={18} /> Quản trị nội dung (Admin)
                  </NavLink>
                  <NavLink to="/duyet-mo-phong" onClick={() => setMobileMenuOpen(false)}>
                    <Clapperboard size={18} /> Duyệt mô phỏng (Admin)
                  </NavLink>
                </>
              )}
              <button type="button" onClick={() => void logout()}>
                <LogOut size={18} /> Đăng xuất khỏi hệ thống
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>
);
