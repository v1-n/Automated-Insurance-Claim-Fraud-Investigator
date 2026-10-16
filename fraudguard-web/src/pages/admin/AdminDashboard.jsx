import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import {
  getAdminDashboard,
  getAllClaimsAdmin,
} from "../../services/adminService";
import {
  LayoutDashboard, FileText, Clock, CheckCircle2, XCircle,
  ShieldAlert, AlertTriangle, Loader2, Users, Activity,
  ArrowRight, UserCheck, ThumbsUp, ThumbsDown, X, Send,
  BarChart3, Eye, TrendingUp,
} from "lucide-react";
import {
  AreaChart, Area, PieChart, Pie, Cell, Legend,
  XAxis, YAxis, CartesianGrid, Tooltip as RechartsTooltip, ResponsiveContainer
} from "recharts";

const DUMMY_TREND_DATA = [
  { month: "Jan", claims: 32, fraud: 4 },
  { month: "Feb", claims: 45, fraud: 6 },
  { month: "Mar", claims: 38, fraud: 5 },
  { month: "Apr", claims: 55, fraud: 9 },
  { month: "May", claims: 62, fraud: 11 },
  { month: "Jun", claims: 48, fraud: 7 },
];

// ── Helpers ──────────────────────────────d──────────────────────────────────
function pretty(str) {
  return str?.replace(/_/g, " ").toLowerCase().replace(/\b\w/g, c => c.toUpperCase()) || "—";
}
function fmtDate(raw) {
  if (!raw) return "—";
  return new Date(raw).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" });
}
function fmtAmount(n) {
  return `₹${Number(n).toLocaleString("en-IN")}`;
}

// ── Status badge ──────────────────────────────────────────────────────────
function StatusBadge({ status }) {
  const map = {
    APPROVED:     { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
    UNDER_REVIEW: { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
    PENDING:      { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
    REJECTED:     { cls: "bg-red-50 text-red-700 ring-red-200" },
    FLAGGED:      { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-600 ring-slate-200" };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ${cfg.cls}`}>
      {pretty(status)}
    </span>
  );
}

function FraudBadge({ status }) {
  const map = {
    SUSPICIOUS:      { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
    CONFIRMED_FRAUD: { cls: "bg-red-50 text-red-700 ring-red-200" },
    CLEARED:         { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-500 ring-slate-200" };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ${cfg.cls}`}>
      {status ? pretty(status) : "Unreviewed"}
    </span>
  );
}

// ── Stat card ─────────────────────────────────────────────────────────────
function StatCard({ icon: Icon, iconBg, label, value, loading }) {
  return (
    <div className="bg-white rounded-xl border border-slate-200 p-5 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow">
      <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl ${iconBg}`}>
        <Icon className="h-5 w-5" />
      </div>
      <div>
        <p className="text-xs font-medium text-slate-500 uppercase tracking-wide">{label}</p>
        {loading ? (
          <div className="mt-1 h-6 w-10 rounded bg-slate-100 animate-pulse" />
        ) : (
          <p className="text-2xl font-bold text-slate-900">{value}</p>
        )}
      </div>
    </div>
  );
}

// ── Action modal ──────────────────────────────────────────────────────────
function ActionModal({ title, children, onClose }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 p-6" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-slate-900">{title}</h3>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-600 transition-colors">
            <X className="h-5 w-5" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

// ── Main ──────────────────────────────────────────────────────────────────
export default function AdminDashboard() {
  const navigate = useNavigate();

  const [dashboard, setDashboard] = useState(null);
  const [claims, setClaims]       = useState([]);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState("");

  // modal state
  const [modalError, setModalError] = useState("");

  useEffect(() => { fetchAll(); }, []);

  const fetchAll = async () => {
    try {
      setLoading(true);
      setError("");
      const [dashRes, claimsRes] = await Promise.all([
        getAdminDashboard(),
        getAllClaimsAdmin(0, 5), // Fetch 5 most recent claims
      ]);
      setDashboard(dashRes.data?.data);
      setClaims(claimsRes.data?.data?.content || []);
    } catch (err) {
      setError("Failed to load dashboard data.");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const d = dashboard || {};

  return (
    <DashboardLayout>
      <div className="space-y-6">

        {/* Header */}
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <LayoutDashboard className="h-6 w-6 text-slate-900" /> Admin Dashboard
          </h1>
          <p className="text-sm text-slate-500 mt-0.5">Overview of all insurance claims and operations.</p>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            <AlertTriangle className="h-4 w-4 shrink-0" /> {error}
            <button onClick={fetchAll} className="ml-auto text-xs text-slate-900 hover:underline">Retry</button>
          </div>
        )}

        {/* Stat cards */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard icon={FileText}     iconBg="bg-slate-100 text-slate-600"     label="Total Claims"    value={d.totalClaims ?? 0}          loading={loading} />
          <StatCard icon={ShieldAlert}  iconBg="bg-slate-100 text-slate-900"     label="Suspected Fraud" value={d.suspectedFraudClaims ?? 0} loading={loading} />
          <StatCard icon={AlertTriangle} iconBg="bg-slate-100 text-slate-900"    label="Confirmed Fraud" value={d.confirmedFraudClaims ?? 0} loading={loading} />
          <StatCard icon={Activity}     iconBg="bg-slate-100 text-slate-900"     label="Active Claims"   value={d.activeClaims ?? 0}         loading={loading} />
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {/* Claims Trend */}
          <div className="bg-white rounded-xl border border-slate-200 shadow-sm">
            <div className="p-6 pb-2">
              <h2 className="text-sm font-medium text-slate-800 flex items-center gap-2">
                <TrendingUp className="h-4 w-4 text-slate-500" />
                Claims & Fraud Trend
              </h2>
            </div>
            <div className="p-6 pt-2">
              <ResponsiveContainer width="100%" height={220}>
                <AreaChart data={DUMMY_TREND_DATA} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorClaims" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.2} />
                      <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="colorFraud" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#ef4444" stopOpacity={0.2} />
                      <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                  <XAxis dataKey="month" tick={{ fontSize: 12, fill: '#64748b' }} tickLine={false} axisLine={false} dy={10} />
                  <YAxis tick={{ fontSize: 12, fill: '#64748b' }} tickLine={false} axisLine={false} />
                  <RechartsTooltip contentStyle={{ borderRadius: '8px', border: '1px solid #e2e8f0', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                  <Legend iconType="circle" wrapperStyle={{ fontSize: '12px', color: '#475569', paddingTop: '10px' }} />
                  <Area type="monotone" dataKey="claims" stroke="#3b82f6" strokeWidth={2} fillOpacity={1} fill="url(#colorClaims)" name="Claims" />
                  <Area type="monotone" dataKey="fraud" stroke="#ef4444" strokeWidth={2} fillOpacity={1} fill="url(#colorFraud)" name="Fraud" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Status Distribution */}
          <div className="bg-white rounded-xl border border-slate-200 shadow-sm">
            <div className="p-6 pb-2">
              <h2 className="text-sm font-medium text-slate-800 flex items-center gap-2">
                <PieChart className="w-4 h-4 text-slate-500" />
                Claim Status Distribution
              </h2>
            </div>
            <div className="p-6 pt-2 flex items-center justify-center gap-8">
              <ResponsiveContainer width="55%" height={220}>
                <PieChart>
                  <Pie
                    data={[
                      { name: "Pending", value: d.pendingClaims || 0, color: "#94a3b8" },
                      { name: "Under Review", value: d.underReviewClaims || 0, color: "#f59e0b" },
                      { name: "Approved", value: d.approvedClaims || 0, color: "#10b981" },
                      { name: "Rejected", value: d.rejectedClaims || 0, color: "#ef4444" },
                    ]}
                    cx="50%" cy="50%"
                    innerRadius={55} outerRadius={85}
                    paddingAngle={3}
                    dataKey="value"
                  >
                    {[
                      { name: "Pending", value: d.pendingClaims || 0, color: "#94a3b8" },
                      { name: "Under Review", value: d.underReviewClaims || 0, color: "#f59e0b" },
                      { name: "Approved", value: d.approvedClaims || 0, color: "#10b981" },
                      { name: "Rejected", value: d.rejectedClaims || 0, color: "#ef4444" },
                    ].map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <RechartsTooltip contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                </PieChart>
              </ResponsiveContainer>
              <div className="flex flex-col gap-3 min-w-[140px]">
                {[
                  { name: "Pending", value: d.pendingClaims || 0, color: "#94a3b8" },
                  { name: "Under Review", value: d.underReviewClaims || 0, color: "#f59e0b" },
                  { name: "Approved", value: d.approvedClaims || 0, color: "#10b981" },
                  { name: "Rejected", value: d.rejectedClaims || 0, color: "#ef4444" },
                ].map((item) => (
                  <div key={item.name} className="flex items-center text-sm">
                    <div className="h-3 w-3 rounded-full mr-2.5 shrink-0" style={{ backgroundColor: item.color }} />
                    <span className="text-slate-500 whitespace-nowrap">{item.name}</span>
                    <span className="font-medium text-slate-900 ml-auto pl-4">{item.value}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>



        {/* Recent Claims Table */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100">
              <h2 className="text-sm font-semibold text-slate-800">Recent Claims</h2>
              <button 
                onClick={() => navigate("/admin/claims")} 
                className="text-xs font-medium text-slate-600 border border-slate-200 px-3 py-1.5 rounded-md hover:bg-slate-50 transition-colors"
              >
                View All
              </button>
            </div>

            {loading ? (
              <div className="flex items-center justify-center py-12 gap-2 text-slate-400">
                <Loader2 className="h-5 w-5 animate-spin" /> <span className="text-sm">Loading…</span>
              </div>
            ) : claims.length === 0 ? (
              <div className="flex flex-col items-center py-14 text-slate-400">
                <FileText className="h-10 w-10 mb-3 text-slate-300" />
                <p className="text-sm font-medium text-slate-600">No recent claims</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-slate-100 bg-slate-50/60">
                      {["Claim Number", "Customer", "Amount", "Status", "Fraud Status", "Date", "Actions"].map(h => (
                        <th key={h} className={`px-5 py-3 text-left text-[11px] font-semibold uppercase tracking-wide text-slate-500 ${h === 'Actions' ? 'text-center' : ''}`}>
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {claims.map(claim => (
                      <tr key={claim.claimId} className="hover:bg-slate-50 transition-colors">
                        <td className="px-5 py-4 font-medium text-slate-900 whitespace-nowrap">
                          {claim.claimNumber}
                        </td>
                        <td className="px-5 py-4 text-slate-600 whitespace-nowrap">
                          {claim.customerName || "—"}
                        </td>
                        <td className="px-5 py-4 text-slate-900 font-medium whitespace-nowrap">
                          {fmtAmount(claim.claimAmount)}
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <StatusBadge status={claim.claimStatus} />
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <FraudBadge status={claim.fraudStatus} />
                        </td>
                        <td className="px-5 py-4 text-slate-500 whitespace-nowrap">
                          {fmtDate(claim.incidentDate || claim.createdAt)}
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap text-center">
                          <button onClick={() => navigate(`/admin/claims/${claim.claimId}`)}
                            title="View Claim"
                            className="p-1.5 rounded-md text-slate-400 hover:text-slate-900 hover:bg-slate-100 transition-colors inline-flex">
                            <Eye className="h-4 w-4" />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
      </div>
    </DashboardLayout>
  );
}
