import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { CalendarDays, Gauge, LoaderCircle, MessageSquareText, ShieldAlert, UserRound } from 'lucide-react';
import { api } from '../../api';
import type { Profile } from '../../api';
import './account.css';

type AccountProfile = Profile & { createdAt: string };
type Quota = { tokenQuota: number; tokenBalance: number; reservedTokens: number; availableTokens: number };
type DailyUsage = { date: string; completedTurns: number; violationTurns: number; tokensUsed: number };
type UserUsage = { userId: string; username: string; completedTurns: number; violationTurns: number; tokensUsed: number };
type UsageReport = {
  scope: 'User' | 'All'; from: string; to: string;
  totals: { completedTurns: number; failedTurns: number; violationTurns: number; tokensUsed: number; tokensSettled: number; usageUnknownTurns: number; activeUsers: number };
  daily: DailyUsage[]; topUsers: UserUsage[]; quota: Quota | null;
};

const number = (value: number) => value.toLocaleString('vi-VN');
const shortDate = (value: string) => new Date(value).toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' });

export function AccountPage({ user }: { user: Profile }) {
  const [profile, setProfile] = useState<AccountProfile>({ ...user, createdAt: '' });
  const [quota, setQuota] = useState<Quota | null>(null);
  const [report, setReport] = useState<UsageReport | null>(null);
  const [allUsers, setAllUsers] = useState<UsageReport | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const isAdmin = user.role === 'Admin';

  useEffect(() => {
    const controller = new AbortController();
    const signal = controller.signal;
    // An admin's own report is scoped to them explicitly; the system-wide view is loaded separately.
    Promise.all([
      api<AccountProfile>('/auth/profile', { signal }).then(setProfile),
      api<Quota>('/account/quota', { signal }).then(setQuota),
      api<UsageReport>(`/reports/usage${isAdmin ? `?userId=${user.id}` : ''}`, { signal }).then(setReport),
      isAdmin ? api<UsageReport>('/reports/usage', { signal }).then(setAllUsers) : Promise.resolve(),
    ]).catch(e => { if (!signal.aborted) setError(e.message); }).finally(() => { if (!signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [user.id, isAdmin]);

  const used = quota ? Math.max(0, quota.tokenQuota - quota.tokenBalance) : 0;
  const percent = (value: number) => quota && quota.tokenQuota > 0 ? Math.min(100, (value / quota.tokenQuota) * 100) : 0;

  return <main className="account-page">
    <header className="account-header">
      <span className="eyebrow">TÀI KHOẢN</span>
      <h1>Xin chào, {profile.username}</h1>
      <p className="muted">Thông tin tài khoản, hạn mức token và mức sử dụng hỏi đáp của bạn.</p>
    </header>
    {error && <p role="alert" className="error">{error}</p>}

    <section className="account-grid">
      <article className="account-card">
        <h2><UserRound size={16}/>Hồ sơ</h2>
        <dl className="account-facts">
          <dt>Tên người dùng</dt><dd>{profile.username}</dd>
          <dt>Email</dt><dd>{profile.email}</dd>
          <dt>Vai trò</dt><dd>{profile.role === 'Admin' ? 'Quản trị viên' : 'Thành viên'}</dd>
          <dt>Tham gia</dt><dd>{profile.createdAt ? new Date(profile.createdAt).toLocaleDateString('vi-VN') : '—'}</dd>
        </dl>
      </article>

      <article className="account-card">
        <h2><Gauge size={16}/>Hạn mức token</h2>
        {!quota ? <Loading busy={loading}/> : <>
          <div className="quota-figure"><strong>{number(quota.availableTokens)}</strong><span>/ {number(quota.tokenQuota)} khả dụng</span></div>
          <div className="quota-meter" role="img" aria-label={`Đã dùng ${number(used)}, đang giữ chỗ ${number(quota.reservedTokens)}`}>
            <span className="quota-used" style={{ width: `${percent(used)}%` }}/>
            <span className="quota-held" style={{ width: `${percent(quota.reservedTokens)}%` }}/>
          </div>
          <ul className="quota-legend">
            <li><i className="quota-used"/>Đã dùng {number(used)}</li>
            <li><i className="quota-held"/>Đang giữ chỗ {number(quota.reservedTokens)}</li>
            <li><i/>Số dư {number(quota.tokenBalance)}</li>
          </ul>
          {quota.reservedTokens > 0 && <p className="muted">Phần giữ chỗ là câu hỏi đang xử lý hoặc chờ quyết toán; sẽ được trả lại nếu câu hỏi lỗi.</p>}
        </>}
      </article>
    </section>

    <UsageSection title="Mức sử dụng của bạn" report={report} loading={loading}/>
    {isAdmin && <UsageSection title="Toàn hệ thống" report={allUsers} loading={loading} showUsers/>}
  </main>;
}

function UsageSection({ title, report, loading, showUsers = false }: { title: string; report: UsageReport | null; loading: boolean; showUsers?: boolean }) {
  if (!report) return <section className="account-card usage"><h2><CalendarDays size={16}/>{title}</h2><Loading busy={loading}/></section>;
  const peak = Math.max(1, ...report.daily.map(d => d.completedTurns));
  const { totals } = report;
  return <section className="account-card usage">
    <h2><CalendarDays size={16}/>{title}<small>{shortDate(report.from)} – {shortDate(report.to)} · giờ Việt Nam</small></h2>
    <div className="usage-stats">
      <Stat icon={<MessageSquareText size={15}/>} label="Câu hỏi đã trả lời" value={number(totals.completedTurns)}/>
      <Stat label="Token đã dùng" value={number(totals.tokensUsed)}/>
      <Stat label="Lỗi / không xác định" value={`${number(totals.failedTurns)} / ${number(totals.usageUnknownTurns)}`}/>
      <Stat icon={<ShieldAlert size={15}/>} label="Bị chặn vi phạm" value={number(totals.violationTurns)}/>
      {showUsers && <Stat label="Người dùng hoạt động" value={number(totals.activeUsers)}/>}
    </div>
    <div className="usage-chart" role="img" aria-label="Số câu hỏi theo ngày">
      {report.daily.map(day => <span key={day.date} title={`${shortDate(day.date)}: ${day.completedTurns} câu, ${number(day.tokensUsed)} token`}
        style={{ height: `${Math.max(2, (day.completedTurns / peak) * 100)}%` }} className={day.completedTurns ? '' : 'empty'}/>)}
    </div>
    <div className="usage-axis"><span>{shortDate(report.from)}</span><span>{shortDate(report.to)}</span></div>
    {showUsers && <table className="usage-table">
      <thead><tr><th>Người dùng</th><th>Câu hỏi</th><th>Vi phạm</th><th>Token</th></tr></thead>
      <tbody>{report.topUsers.length === 0
        ? <tr><td colSpan={4} className="muted">Chưa có lượt hỏi đáp trong khoảng này.</td></tr>
        : report.topUsers.map(u => <tr key={u.userId}><td>{u.username}</td><td>{number(u.completedTurns)}</td><td>{number(u.violationTurns)}</td><td>{number(u.tokensUsed)}</td></tr>)}
      </tbody>
    </table>}
  </section>;
}

function Stat({ icon, label, value }: { icon?: ReactNode; label: string; value: string }) {
  return <div className="usage-stat"><span>{icon}{label}</span><strong>{value}</strong></div>;
}

function Loading({ busy }: { busy: boolean }) {
  return <p className="muted account-loading">{busy ? <><LoaderCircle size={14} className="spin"/>Đang tải…</> : 'Không có dữ liệu.'}</p>;
}
