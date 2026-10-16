import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { getAllClaims } from "../../services/claimService";
import { getUser } from "../../utils/auth";
import {
  FileText, Plus, Clock, CheckCircle2,
  XCircle, AlertTriangle, ArrowRight, Loader2,
} from "lucide-react";

// ── Status badge ──────────────────────────────────────────────────────────────
function StatusBadge({ status }) {
  const map = {
    APPROVED:     { cls: "bg-slate-50 text-slate-900 ring-slate-200",  label: "Approved" },
    UNDER_REVIEW: { cls: "bg-slate-50 text-slate-900 ring-slate-200",        label: "Under Review" },
    PENDING:      { cls: "bg-slate-50 text-slate-900 ring-slate-200",           label: "Pending" },
    REJECTED:     { cls: "bg-red-50 text-red-700 ring-red-200",              label: "Rejected" },
    FLAGGED:      { cls: "bg-slate-50 text-slate-900 ring-slate-200",     label: "Flagged" },
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-600 ring-slate-200", label: status };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ${cfg.cls}`}>
      {cfg.label}
    </span>
  );
}

// ── Stat card ─────────────────────────────────────────────────────────────────
function StatCard({ icon: Icon, label, value, loading, subtext }) {
  return (
    <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition-shadow flex flex-col justify-between">
      <div className="flex justify-between items-start mb-4">
        <p className="text-sm font-medium text-slate-700">{label}</p>
        <Icon className="h-4 w-4 text-slate-400" />
      </div>
      <div>
        {loading ? (
          <div className="h-8 w-10 rounded bg-slate-100 animate-pulse" />
        ) : (
          <p className="text-2xl font-bold text-slate-900">{value}</p>
        )}
        {subtext && <p className="text-xs text-slate-400 mt-1">{subtext}</p>}
      </div>
    </div>
  );
}

// ── Main dashboard ────────────────────────────────────────────────────────────
export default function CustomerDashboard() {
  const navigate = useNavigate();
  const user = getUser();

  const [claims, setClaims]   = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await getAllClaims(0, 10, "CREATED_AT", "DESC");
        setClaims(res.data?.data?.content || []);
      } catch (err) {
        setError("Could not load claims.");
        console.error(err);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const total    = claims.length;
  const pending  = claims.filter(c => ["PENDING", "UNDER_REVIEW"].includes(c.claimStatus)).length;
  const approved = claims.filter(c => c.claimStatus === "APPROVED").length;
  const rejected = claims.filter(c => c.claimStatus === "REJECTED").length;
  const recent   = claims.slice(0, 5);

  const greeting = () => {
    const h = new Date().getHours();
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">

        {/* ── Page header ── */}
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">
              {greeting()}, {user?.fullName?.split(" ")[0] || "there"}
            </h1>
            <p className="text-sm text-slate-500 mt-0.5">
              Here's a summary of your insurance claims.
            </p>
          </div>
          <button
            onClick={() => navigate("/customer/claims/new")}
            className="flex items-center gap-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-sm font-medium px-4 py-2 transition-colors shadow-sm shrink-0"
          >
            <Plus className="h-4 w-4" />
            New Claim
          </button>
        </div>

        {/* ── Stat cards ── */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard icon={FileText}     label="Total Claims" value={total}    loading={loading} />
          <StatCard icon={Clock}        label="In Review"    value={pending}  loading={loading} />
          <StatCard icon={CheckCircle2} label="Approved"     value={approved} loading={loading} />
          <StatCard icon={XCircle}      label="Rejected"     value={rejected} loading={loading} />
        </div>

        {/* ── Recent Claims table ── */}
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100">
            <div>
              <h2 className="text-sm font-semibold text-slate-800">Recent Claims</h2>
              <p className="text-xs text-slate-400 mt-0.5">Your 5 most recent submissions</p>
            </div>
            <button
              onClick={() => navigate("/customer/claims")}
              className="flex items-center gap-1 text-xs font-medium text-slate-900 hover:text-slate-700 transition-colors"
            >
              View all <ArrowRight className="h-3.5 w-3.5" />
            </button>
          </div>

          {loading ? (
            <div className="flex items-center justify-center py-12 gap-2 text-slate-400">
              <Loader2 className="h-5 w-5 animate-spin" />
              <span className="text-sm">Loading claims…</span>
            </div>
          ) : error ? (
            <div className="flex items-center justify-center py-12 gap-2 text-red-500">
              <AlertTriangle className="h-5 w-5" />
              <span className="text-sm">{error}</span>
            </div>
          ) : recent.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-14 text-slate-400">
              <FileText className="h-10 w-10 mb-3 text-slate-300" />
              <p className="text-sm font-medium text-slate-600">No claims yet</p>
              <p className="text-xs mt-1">Submit your first claim to get started</p>
              <button
                onClick={() => navigate("/customer/claims/new")}
                className="mt-4 flex items-center gap-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-xs font-medium px-4 py-2 transition-colors"
              >
                <Plus className="h-3.5 w-3.5" /> Submit Claim
              </button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-100 bg-slate-50/60">
                    {["Claim #", "Type", "Amount", "Date", "Status"].map(h => (
                      <th key={h} className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {recent.map((claim) => (
                    <tr key={claim.claimId} onClick={() => navigate("/customer/claims")} className="hover:bg-slate-50 cursor-pointer transition-colors">
                      <td className="px-5 py-3.5 font-medium text-slate-900">{claim.claimNumber}</td>
                      <td className="px-5 py-3.5 text-slate-600 capitalize">{claim.claimType?.toLowerCase().replace(/_/g, " ") || "—"}</td>
                      <td className="px-5 py-3.5 text-slate-700 font-medium">₹{Number(claim.claimAmount).toLocaleString("en-IN")}</td>
                      <td className="px-5 py-3.5 text-slate-500">
                        {claim.incidentDate ? new Date(claim.incidentDate).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" }) : "—"}
                      </td>
                      <td className="px-5 py-3.5"><StatusBadge status={claim.claimStatus} /></td>
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