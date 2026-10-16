import { useEffect, useState } from "react";
import DashboardLayout from "../../components/DashboardLayout";
import { getInvestigatorsWorkload } from "../../services/adminService";
import { Loader2, AlertTriangle, Users, Shield, CheckCircle, Mail } from "lucide-react";

export default function AdminWorkloadPage() {
  const [workload, setWorkload] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => { fetchWorkload(); }, []);

  const fetchWorkload = async () => {
    try { 
      setLoading(true); 
      setError("");
      const res = await getInvestigatorsWorkload();
      setWorkload(res.data?.data || []);
    } catch { 
      setError("Failed to load investigator workload."); 
    } finally { 
      setLoading(false); 
    }
  };

  // Calculations
  const activeInvestigators = workload.length;
  const totalActiveClaims = workload.reduce((acc, curr) => acc + (curr.activeClaims || 0), 0);
  const totalReviewsDone = workload.reduce((acc, curr) => acc + (curr.reviewsCompleted || 0), 0);

  return (
    <DashboardLayout>
      <div className="space-y-6">
        
        {/* ── Header ── */}
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Investigator Workload</h1>
          <p className="text-sm text-slate-500 mt-1">
            Monitor investigator assignments and performance
          </p>
        </div>

        {error && (
          <div className="flex items-center gap-2 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            <AlertTriangle className="h-4 w-4 shrink-0" /> {error}
            <button onClick={fetchWorkload} className="ml-auto text-xs text-slate-900 hover:underline">Retry</button>
          </div>
        )}

        {/* ── Stats Cards ── */}
        {!loading && !error && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-medium text-slate-800">Active Investigators</h3>
                <Users className="h-4 w-4 text-slate-400" />
              </div>
              <div>
                <p className="text-2xl font-bold text-slate-900">{activeInvestigators}</p>
                <p className="text-xs text-transparent select-none mt-1">Spacer</p> {/* To align visually */}
              </div>
            </div>

            <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-medium text-slate-800">Total Active Claims</h3>
                <Shield className="h-4 w-4 text-slate-400" />
              </div>
              <div>
                <p className="text-2xl font-bold text-slate-900">{totalActiveClaims}</p>
                <p className="text-xs text-slate-500 mt-1">Across all investigators</p>
              </div>
            </div>

            <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-medium text-slate-800">Total Reviews Done</h3>
                <CheckCircle className="h-4 w-4 text-slate-400" />
              </div>
              <div>
                <p className="text-2xl font-bold text-slate-900">{totalReviewsDone}</p>
                <p className="text-xs text-slate-500 mt-1">All time</p>
              </div>
            </div>
          </div>
        )}

        {/* ── Table Section ── */}
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b border-slate-100">
            <h2 className="text-sm font-semibold text-slate-800">Investigator Directory</h2>
          </div>

          {loading ? (
            <div className="flex items-center justify-center py-20 gap-2 text-slate-400">
              <Loader2 className="h-6 w-6 animate-spin" /> <span>Loading workload data…</span>
            </div>
          ) : workload.length === 0 ? (
            <div className="flex flex-col items-center py-20 text-slate-400">
              <Users className="h-12 w-12 mb-3 text-slate-300" />
              <p className="text-sm font-medium text-slate-600">No investigators found</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-100 bg-slate-50/60">
                    {["Investigator", "Email", "Active Claims", "Reviews Completed", "Status"].map(h => (
                      <th key={h} className="px-5 py-4 text-left text-xs font-semibold tracking-wide text-slate-500">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {workload.map(inv => {
                    const initials = inv.fullName?.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2) || "??";
                    const maxClaims = Math.max(...workload.map(w => w.activeClaims), 10);
                    const pct = Math.min(Math.round((inv.activeClaims / maxClaims) * 100), 100);

                    return (
                      <tr key={inv.investigatorId} className="hover:bg-slate-50 transition-colors group">
                        <td className="px-5 py-4 whitespace-nowrap">
                          <div className="flex items-center gap-3">
                            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-slate-200 text-slate-700 text-xs font-bold shrink-0">
                              {initials}
                            </div>
                            <span className="font-medium text-slate-900">{inv.fullName}</span>
                          </div>
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <div className="flex items-center gap-2 text-slate-500">
                            <Mail className="h-3.5 w-3.5" />
                            <span>{inv.email || "—"}</span>
                          </div>
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <div className="flex items-center gap-3">
                            <div className="h-1.5 w-16 bg-slate-100 rounded-full overflow-hidden">
                              <div className="h-full bg-blue-500 rounded-full" style={{ width: `${pct}%` }} />
                            </div>
                            <span className="font-medium text-slate-900">{inv.activeClaims}</span>
                          </div>
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <span className="font-medium text-slate-900">{inv.reviewsCompleted}</span>
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-semibold tracking-wider capitalize ${
                            inv.status === 'ACTIVE' ? 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200' : 'bg-slate-50 text-slate-700 ring-1 ring-slate-200'
                          }`}>
                            {inv.status?.toLowerCase() || "Active"}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </DashboardLayout>
  );
}
