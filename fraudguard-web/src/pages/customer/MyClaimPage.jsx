import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { getAllClaims } from "../../services/claimService";
import {
  FileText, Plus, Loader2, AlertTriangle,
  ChevronLeft, ChevronRight, Eye, Search, Filter
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

const SORT_OPTIONS = [
  { value: "CREATED_AT",   label: "Created Date" },
  { value: "CLAIM_AMOUNT", label: "Amount" },
  { value: "INCIDENT_DATE",label: "Incident Date" },
  { value: "CLAIM_STATUS", label: "Status" },
];

export default function MyClaimPage() {
  const navigate = useNavigate();

  const [claims, setClaims]       = useState([]);
  const [loading, setLoading]     = useState(true);
  const [error, setError]         = useState(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [pageNo, setPageNo]       = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [totalElements, setTotalElements] = useState(0);
  const PAGE_SIZE = 6;

  useEffect(() => {
    fetchClaims();
  }, [pageNo]);

  const fetchClaims = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await getAllClaims(pageNo, PAGE_SIZE, "CREATED_AT", "DESC");
      const data = res.data?.data;
      setClaims(data?.content || []);
      setTotalPages(data?.totalPages || 0);
      setTotalElements(data?.totalElements || 0);
    } catch (err) {
      setError("Failed to load claims. Please try again.");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filteredClaims = claims.filter(claim => {
    const matchesSearch = claim.claimNumber.toLowerCase().includes(searchTerm.toLowerCase()) || 
                          (claim.claimType && claim.claimType.toLowerCase().includes(searchTerm.toLowerCase()));
    const matchesStatus = statusFilter === "ALL" || claim.claimStatus === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <DashboardLayout>
      <div className="space-y-5">

        {/* ── Header ── */}
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">My Claims</h1>
            <p className="text-sm text-slate-500 mt-0.5">
              View and track all your insurance claims
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

        {/* ── Filter bar ── */}
        <div className="flex items-center gap-4 flex-wrap">
          <div className="flex-1 min-w-[200px] max-w-sm relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search claims..." 
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-200 transition-colors"
            />
          </div>
          
          <div className="flex items-center gap-2">
            <Filter className="h-4 w-4 text-slate-400" />
            <select
              value={statusFilter}
              onChange={e => setStatusFilter(e.target.value)}
              className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-200 cursor-pointer"
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
            <>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-slate-100 bg-slate-50/60">
                      {["Claim Number", "Type", "Amount", "Status", "Fraud Status", "Date", "Details"].map(h => (
                        <th key={h} className="px-5 py-4 text-left text-xs font-semibold tracking-wide text-slate-500">{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredClaims.map((claim) => (
                      <tr
                        key={claim.claimId}
                        onClick={() => navigate(`/customer/claims/${claim.claimId}`)}
                        className="hover:bg-slate-50/50 cursor-pointer transition-colors group"
                      >
                        <td className="px-5 py-4 font-medium text-slate-900">{claim.claimNumber}</td>
                        <td className="px-5 py-4 text-slate-600 capitalize">
                          {claim.claimType?.toLowerCase().replace(/_/g, " ") || "—"}
                        </td>
                        <td className="px-5 py-4 text-slate-900 font-medium">
                          ${Number(claim.claimAmount).toLocaleString("en-US")}
                        </td>
                        <td className="px-5 py-4">
                          <StatusBadge status={claim.claimStatus} />
                        </td>
                        <td className="px-5 py-4">
                          <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wider ${
                            claim.fraudStatus === "SUSPICIOUS"
                              ? "bg-slate-100 text-slate-900"
                              : claim.fraudStatus === "CONFIRMED_FRAUD"
                              ? "bg-red-100 text-red-700"
                              : claim.fraudStatus === "PENDING_REVIEW"
                              ? "bg-slate-100 text-slate-700"
                              : "bg-slate-100 text-slate-900"
                          }`}>
                            {claim.fraudStatus?.replace(/_/g, " ") || "CLEAR"}
                          </span>
                        </td>
                        <td className="px-5 py-4 text-slate-500">
                          {claim.incidentDate
                            ? new Date(claim.incidentDate).toLocaleDateString("en-US")
                            : "—"}
                        </td>
                        <td className="px-5 py-4">
                          <div className="flex items-center gap-1.5 text-sm font-medium text-slate-900">
                            <Eye className="h-4 w-4" /> View
                          </div>
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
