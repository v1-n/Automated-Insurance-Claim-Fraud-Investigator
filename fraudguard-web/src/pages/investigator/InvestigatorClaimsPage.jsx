import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { getAssignedClaims } from "../../services/investigatorService";
import {
  FileText, Loader2, AlertTriangle,
  Search, Filter, ShieldCheck
} from "lucide-react";

// ── Status badge ──────────────────────────────────────────────────────────────
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

export default function InvestigatorClaimsPage() {
  const navigate = useNavigate();

  const [claims, setClaims]       = useState([]);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [pageNo, setPageNo]       = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const PAGE_SIZE = 10;

  useEffect(() => {
    fetchClaims();
  }, [pageNo]);

  const fetchClaims = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await getAssignedClaims(pageNo, PAGE_SIZE, "CREATED_AT", "DESC");
      const data = res.data?.data;
      setClaims(data?.content || []);
      setTotalPages(data?.totalPages || 0);
      setTotalElements(data?.totalElements || 0);
    } catch (err) {
      setError("Failed to load assigned claims. Please try again.");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filteredClaims = claims.filter(claim => {
    const term = searchTerm.toLowerCase();
    const typeStr = claim.claimType ? claim.claimType.replace(/_/g, " ").toLowerCase() : "";
    const matchesSearch = 
      (claim.claimNumber && claim.claimNumber.toLowerCase().includes(term)) || 
      (claim.customerName && claim.customerName.toLowerCase().includes(term)) ||
      (typeStr.includes(term));
    const matchesStatus = statusFilter === "ALL" || claim.claimStatus === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <DashboardLayout>
      <div className="space-y-6">

        {/* ── Header ── */}
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Assigned Claims</h1>
          <p className="text-sm text-slate-500 mt-1">
            Claims assigned to you for investigation
          </p>
        </div>

        {/* ── Filter bar ── */}
        <div className="flex items-center gap-4 flex-wrap">
          <div className="flex-1 min-w-[200px] max-w-sm relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search claims or customer..." 
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-200 transition-colors"
            />
          </div>
          
          <div className="flex items-center gap-2">
            <div className="relative flex items-center">
              <Filter className="absolute left-3 h-4 w-4 text-slate-400" />
              <select
                value={statusFilter}
                onChange={e => setStatusFilter(e.target.value)}
                className="pl-9 pr-8 py-2 rounded-lg border border-slate-200 bg-slate-50 text-sm font-medium text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-200 cursor-pointer appearance-none"
              >
                <option value="ALL">All Statuses</option>
                <option value="PENDING">Pending</option>
                <option value="UNDER_REVIEW">Under Review</option>
                <option value="INVESTIGATION_COMPLETED">Investigation Completed</option>
                <option value="APPROVED">Approved</option>
                <option value="REJECTED">Rejected</option>
                <option value="CLOSED">Closed</option>
              </select>
            </div>
            <span className="inline-flex items-center px-2.5 py-1 rounded text-xs font-medium bg-slate-100 text-slate-600 ml-2">
              {totalElements} claims
            </span>
          </div>
        </div>

        {/* ── Table card ── */}
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
          {loading ? (
            <div className="flex items-center justify-center py-16 gap-2 text-slate-400">
              <Loader2 className="h-5 w-5 animate-spin" />
              <span className="text-sm">Loading claims…</span>
            </div>
          ) : error ? (
            <div className="flex flex-col items-center justify-center py-16 gap-3 text-red-500">
              <AlertTriangle className="h-8 w-8" />
              <p className="text-sm font-medium">{error}</p>
              <button onClick={fetchClaims} className="text-xs text-slate-900 hover:underline">Retry</button>
            </div>
          ) : filteredClaims.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-slate-400">
              <ShieldCheck className="h-10 w-10 mb-3 text-slate-300" />
              <p className="text-sm font-medium text-slate-600">No assigned claims found</p>
            </div>
          ) : (
            <>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-slate-100 bg-slate-50/60">
                      {["Claim Number", "Customer", "Amount", "Fraud Status", "Claim Status", "Date", "Action"].map(h => (
                        <th key={h} className={`px-6 py-3 text-left text-[11px] font-semibold tracking-wide text-slate-500 ${h === 'Action' ? 'text-center' : ''}`}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredClaims.map((claim) => (
                      <tr
                        key={claim.claimId}
                        onClick={() => navigate(`/investigator/claims/${claim.claimId}`)}
                        className="hover:bg-slate-50 transition-colors group cursor-pointer"
                      >
                        <td className="px-6 py-4 font-medium text-slate-900 whitespace-nowrap">
                          {claim.claimNumber}
                        </td>
                        <td className="px-6 py-4 text-slate-600 whitespace-nowrap">
                          <div className="text-sm font-medium text-slate-900">{claim.customerName || "—"}</div>
                          {claim.customerEmail && <div className="text-xs text-slate-500">{claim.customerEmail}</div>}
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
                        <td className="px-6 py-4 text-slate-500 whitespace-nowrap">
                          {claim.incidentDate
                            ? new Date(claim.incidentDate).toLocaleDateString("en-US")
                            : "—"}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-center">
                          <button
                            onClick={() => navigate(`/investigator/claims/${claim.claimId}`)}
                            className="inline-flex items-center gap-1.5 px-4 py-1.5 bg-slate-900 text-white rounded-lg text-xs font-medium hover:bg-slate-800 transition-colors"
                          >
                            <FileText className="h-3.5 w-3.5" />
                            Review
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* ── Pagination ── */}
              {totalPages > 1 && (
                <div className="flex items-center justify-between px-5 py-4 border-t border-slate-100 bg-white">
                  <p className="text-xs text-slate-500 font-medium">
                    Showing {totalElements === 0 ? 0 : pageNo * PAGE_SIZE + 1}–{Math.min((pageNo + 1) * PAGE_SIZE, totalElements)} of {totalElements}
                  </p>
                  <div className="inline-flex items-center -space-x-px rounded-md shadow-sm">
                    <button
                      disabled={pageNo === 0}
                      onClick={() => setPageNo(p => p - 1)}
                      className="px-3 py-1.5 rounded-l-md border border-slate-200 bg-white text-xs font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                    >
                      Previous
                    </button>
                    {Array.from({ length: totalPages }, (_, i) => (
                      <button
                        key={i}
                        onClick={() => setPageNo(i)}
                        className={`w-8 h-8 flex items-center justify-center border text-xs font-medium transition-colors ${
                          pageNo === i
                            ? "z-10 bg-slate-900 border-slate-900 text-white"
                            : "border-slate-200 bg-white text-slate-600 hover:bg-slate-50"
                        }`}
                      >
                        {i + 1}
                      </button>
                    ))}
                    <button
                      disabled={pageNo >= totalPages - 1}
                      onClick={() => setPageNo(p => p + 1)}
                      className="px-3 py-1.5 rounded-r-md border border-slate-200 bg-white text-xs font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                    >
                      Next
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>

      </div>
    </DashboardLayout>
  );
}