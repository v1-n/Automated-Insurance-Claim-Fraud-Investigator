import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { getAssignedClaims } from "../../services/investigatorService";
import {
  FileText, ShieldAlert, CheckCircle, Clock, Loader2, AlertTriangle
} from "lucide-react";

// Status Badge
function StatusBadge({ status }) {
  const map = {
    APPROVED: { cls: "bg-emerald-50 text-emerald-700 ring-emerald-200", label: "APPROVED" },
    UNDER_REVIEW: { cls: "bg-amber-50 text-amber-700 ring-amber-200", label: "UNDER REVIEW" },
    PENDING: { cls: "bg-slate-50 text-slate-700 ring-slate-200", label: "PENDING" },
    REJECTED: { cls: "bg-red-50 text-red-700 ring-red-200", label: "REJECTED" },
    FLAGGED: { cls: "bg-amber-50 text-amber-700 ring-amber-200", label: "FLAGGED" },
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-600 ring-slate-200", label: status };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-semibold tracking-wider ${cfg.cls}`}>
      {cfg.label}
    </span>
  );
}

// Fraud Badge
function FraudBadge({ status }) {
  const map = {
    SUSPICIOUS: { cls: "bg-amber-50 text-amber-700 ring-amber-200", label: "SUSPECTED" },
    CONFIRMED_FRAUD: { cls: "bg-red-50 text-red-700 ring-red-200", label: "CONFIRMED" },
    CLEARED: { cls: "bg-emerald-50 text-emerald-700 ring-emerald-200", label: "CLEAR" },
    PENDING_REVIEW: { cls: "bg-slate-50 text-slate-700 ring-slate-200", label: "PENDING REVIEW" }
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-500 ring-slate-200", label: status?.replace(/_/g, " ") || "CLEAR" };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-semibold tracking-wider ${cfg.cls}`}>
      {cfg.label}
    </span>
  );
}

export default function InvestigatorDashboard() {
  const navigate = useNavigate();
  const [claims, setClaims] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [stats, setStats] = useState({
    total: 0,
    reviewed: 0,
    highRisk: 0,
    pending: 0
  });

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setLoading(true);
        // Fetch up to 50 claims to derive local stats from recent data
        const res = await getAssignedClaims(0, 50, "CREATED_AT", "DESC");
        const data = res.data?.data;
        const fetchedClaims = data?.content || [];
        
        setClaims(fetchedClaims.slice(0, 5)); // Show only 5 recent claims

        // Calculate stats locally
        const reviewedCount = fetchedClaims.filter(c => 
          c.fraudStatus === 'CLEAR'||
          c.fraudStatus === 'SUSPECTED' ||
          c.fraudStatus === 'CONFIRMED',
        ).length;

        const highRiskCount = fetchedClaims.filter(c => 
          c.fraudStatus === 'SUSPECTED' || 
          c.fraudStatus === 'CONFIRMED'
        ).length;

        const pendingCount = fetchedClaims.filter(c => 
          c.fraudStatus === 'UNDER_REVIEW' || 
          c.fraudStatus === 'PENDING_ANALYSIS'
        ).length;

        setStats({
          total: data?.totalElements || 0,
          reviewed: reviewedCount,
          highRisk: highRiskCount,
          pending: pendingCount
        });

      } catch (err) {
        setError("Failed to load dashboard data");
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchDashboardData();
  }, []);

  const statCards = [
    {
      title: "Assigned Claims",
      value: stats.total,
      icon: FileText,
      sub: "Total assigned",
    },
    {
      title: "Claims Reviewed",
      value: stats.reviewed,
      icon: CheckCircle,
      sub: "This month",
    },
    {
      title: "High Risk",
      value: stats.highRisk,
      icon: ShieldAlert,
      sub: "Suspected or confirmed",
    },
    {
      title: "Pending Reviews",
      value: stats.pending,
      icon: Clock,
      sub: "Awaiting action",
    }
  ];

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Investigator Dashboard</h1>
          <p className="text-sm text-slate-500 mt-1">Your assigned cases and review summary</p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {statCards.map((stat, idx) => {
            const Icon = stat.icon;
            return (
              <div key={idx} className="bg-white rounded-xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition-shadow">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-sm font-semibold text-slate-900">{stat.title}</h3>
                  <Icon className="h-4 w-4 text-slate-400" />
                </div>
                <div>
                  <div className="text-3xl font-bold text-slate-900">{loading ? "—" : stat.value}</div>
                  <p className="text-xs text-slate-500 mt-1">{stat.sub}</p>
                </div>
              </div>
            );
          })}
        </div>

        {/* All Assigned Claims Table */}
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="px-6 py-5 border-b border-slate-100 flex items-center justify-between">
            <h3 className="text-base font-bold text-slate-900">Recent Assigned Claims</h3>
          </div>
          
          {loading ? (
            <div className="flex items-center justify-center py-16 gap-2 text-slate-400">
              <Loader2 className="h-5 w-5 animate-spin" />
              <span className="text-sm">Loading recent claims…</span>
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center py-16 gap-3 text-red-500">
              <AlertTriangle className="h-8 w-8" />
              <p className="text-sm font-medium">{error}</p>
            </div>
          ) : claims.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-slate-400">
              <FileText className="h-10 w-10 mb-3 text-slate-200" />
              <p className="text-sm font-medium text-slate-500">No assigned claims found</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-100 bg-slate-50/60">
                    <th className="px-6 py-3 text-left text-[11px] font-semibold tracking-wide text-slate-500">Claim Number</th>
                    <th className="px-6 py-3 text-left text-[11px] font-semibold tracking-wide text-slate-500">Customer</th>
                    <th className="px-6 py-3 text-left text-[11px] font-semibold tracking-wide text-slate-500">Amount</th>
                    <th className="px-6 py-3 text-left text-[11px] font-semibold tracking-wide text-slate-500">Fraud Status</th>
                    <th className="px-6 py-3 text-left text-[11px] font-semibold tracking-wide text-slate-500">Claim Status</th>
                    <th className="px-6 py-3 text-center text-[11px] font-semibold tracking-wide text-slate-500">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {claims.map((claim) => (
                    <tr 
                      key={claim.claimId} 
                      onClick={() => navigate(`/investigator/claims/${claim.claimId}`)}
                      className="hover:bg-slate-50 transition-colors group cursor-pointer"
                    >
                      <td className="px-6 py-4 font-medium text-slate-900 whitespace-nowrap">
                        {claim.claimNumber}
                      </td>
                      <td className="px-6 py-4 text-slate-600 whitespace-nowrap">
                        {claim.customerName || "—"}
                      </td>
                      <td className="px-6 py-4 text-slate-900 font-medium whitespace-nowrap">
                        ${Number(claim.claimAmount).toLocaleString("en-US")}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <FraudBadge status={claim.fraudStatus} />
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <StatusBadge status={claim.claimStatus} />
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-center">
                        <button
                          onClick={() => navigate(`/investigator/claims/${claim.claimId}`)}
                          className="inline-flex items-center gap-1.5 px-4 py-1.5 bg-slate-900 text-white rounded-lg text-xs font-medium hover:bg-slate-800 transition-colors"
                        >
                          Review
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