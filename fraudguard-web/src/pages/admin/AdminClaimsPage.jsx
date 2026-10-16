import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { 
  getAllClaimsAdmin,
  assignInvestigator,
  approveClaim,
  rejectClaim,
  getInvestigatorsWorkload
} from "../../services/adminService";
import {
  FileText, Loader2, AlertTriangle,
  Search, Filter, UserPlus, CheckCircle, XCircle, Send, X, Eye
} from "lucide-react";

// ── Status badge ──────────────────────────────────────────────────────────────
function StatusBadge({ status }) {
  const map = {
    APPROVED:     { cls: "bg-emerald-50 text-emerald-700 ring-emerald-200",  label: "APPROVED" },
    UNDER_REVIEW: { cls: "bg-amber-50 text-amber-700 ring-amber-200",        label: "UNDER REVIEW" },
    PENDING:      { cls: "bg-slate-50 text-slate-700 ring-slate-200",           label: "PENDING" },
    REJECTED:     { cls: "bg-red-50 text-red-700 ring-red-200",              label: "REJECTED" },
    FLAGGED:      { cls: "bg-amber-50 text-amber-700 ring-amber-200",     label: "FLAGGED" },
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
    SUSPICIOUS:      { cls: "bg-amber-50 text-amber-700 ring-amber-200", label: "SUSPECTED" },
    CONFIRMED_FRAUD: { cls: "bg-red-50 text-red-700 ring-red-200", label: "CONFIRMED" },
    CLEARED:         { cls: "bg-emerald-50 text-emerald-700 ring-emerald-200", label: "CLEAR" },
    PENDING_REVIEW:  { cls: "bg-slate-50 text-slate-700 ring-slate-200", label: "PENDING REVIEW" }
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-500 ring-slate-200", label: status?.replace(/_/g, " ") || "CLEAR" };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-semibold tracking-wider ${cfg.cls}`}>
      {cfg.label}
    </span>
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

export default function AdminClaimsPage() {
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

  // Modals
  const [modal, setModal] = useState(null); // { type: 'assign'|'approve'|'reject', claim }
  const [modalLoading, setModalLoading] = useState(false);
  const [modalError, setModalError] = useState("");
  const [notes, setNotes] = useState("");
  const [selectedInvestigator, setSelectedInvestigator] = useState("");
  const [workload, setWorkload] = useState([]);

  useEffect(() => {
    fetchClaims();
    fetchWorkload();
  }, [pageNo]);

  const fetchClaims = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await getAllClaimsAdmin(pageNo, PAGE_SIZE, "CREATED_AT", "DESC");
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

  const fetchWorkload = async () => {
    try {
      const res = await getInvestigatorsWorkload();
      setWorkload(res.data?.data || []);
    } catch (err) {
      console.error("Failed to load investigators workload", err);
    }
  };

  const handleAssign = async () => {
    if (!selectedInvestigator) { setModalError("Select an investigator."); return; }
    setModalLoading(true); setModalError("");
    try {
      await assignInvestigator(modal.claim.claimId, Number(selectedInvestigator));
      setModal(null); setSelectedInvestigator("");
      fetchClaims();
    } catch (err) {
      setModalError(err.response?.data?.message || "Assignment failed.");
    } finally { setModalLoading(false); }
  };

  const handleDecision = async (type) => {
    if (!notes.trim()) { setModalError("Decision notes are required."); return; }
    setModalLoading(true); setModalError("");
    try {
      const fn = type === "approve" ? approveClaim : rejectClaim;
      await fn(modal.claim.claimId, notes.trim());
      setModal(null); setNotes("");
      fetchClaims();
    } catch (err) {
      setModalError(err.response?.data?.message || "Action failed.");
    } finally { setModalLoading(false); }
  };

  const filteredClaims = claims.filter(claim => {
    const term = searchTerm.toLowerCase();
    const typeStr = claim.claimType ? claim.claimType.replace(/_/g, " ").toLowerCase() : "";
    const matchesSearch = 
      (claim.claimNumber && claim.claimNumber.toLowerCase().includes(term)) || 
      (claim.customerName && claim.customerName.toLowerCase().includes(term)) ||
      (claim.investigatorName && claim.investigatorName.toLowerCase().includes(term)) ||
      (typeStr.includes(term));
    const matchesStatus = statusFilter === "ALL" || claim.claimStatus === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <DashboardLayout>
      <div className="space-y-6">

        {/* ── Header ── */}
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Claims Management</h1>
          <p className="text-sm text-slate-500 mt-1">
            Assign investigators, approve or reject claims
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
              <FileText className="h-10 w-10 mb-3 text-slate-300" />
              <p className="text-sm font-medium text-slate-600">No claims found</p>
            </div>
          ) : (
            <>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-slate-100 bg-slate-50/60">
                      {["Claim Number", "Customer", "Type", "Amount", "Status", "Fraud", "Investigator", "Date", "Actions"].map(h => (
                        <th key={h} className={`px-5 py-3 text-left text-[11px] font-semibold tracking-wide text-slate-500 ${h === 'Actions' ? 'text-center' : ''}`}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredClaims.map((claim) => (
                      <tr
                        key={claim.claimId}
                        className="hover:bg-slate-50 transition-colors group"
                      >
                        <td className="px-5 py-4 font-medium text-slate-900 whitespace-nowrap">
                          <button onClick={() => navigate(`/admin/claims/${claim.claimId}`)} className="hover:underline">
                            {claim.claimNumber}
                          </button>
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <div className="text-sm font-medium text-slate-900">{claim.customerName || "—"}</div>
                        </td>
                        <td className="px-5 py-4 text-slate-600 capitalize whitespace-nowrap">
                          {claim.claimType?.toLowerCase().replace(/_/g, " ") || "—"}
                        </td>
                        <td className="px-5 py-4 text-slate-900 font-medium whitespace-nowrap">
                          ${Number(claim.claimAmount).toLocaleString("en-US")}
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <StatusBadge status={claim.claimStatus} />
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap">
                          <FraudBadge status={claim.fraudStatus} />
                        </td>
                        <td className="px-5 py-4 text-slate-600 whitespace-nowrap">
                          {claim.investigatorName || "—"}
                        </td>
                        <td className="px-5 py-4 text-slate-500 whitespace-nowrap">
                          {claim.incidentDate
                            ? new Date(claim.incidentDate).toLocaleDateString("en-US")
                            : "—"}
                        </td>
                        <td className="px-5 py-4 whitespace-nowrap text-center">
                          <div className="flex items-center justify-center gap-3">
                            <button onClick={() => { setModal({ type: "assign", claim }); setSelectedInvestigator(""); setModalError(""); }}
                              title="Assign Investigator"
                              className="text-blue-600 hover:text-blue-800 transition-colors">
                              <UserPlus className="h-4 w-4" />
                            </button>
                            <button onClick={() => { setModal({ type: "approve", claim }); setNotes(""); setModalError(""); }}
                              title="Approve"
                              className="text-emerald-600 hover:text-emerald-800 transition-colors">
                              <CheckCircle className="h-4 w-4" />
                            </button>
                            <button onClick={() => { setModal({ type: "reject", claim }); setNotes(""); setModalError(""); }}
                              title="Reject"
                              className="text-red-600 hover:text-red-800 transition-colors">
                              <XCircle className="h-4 w-4" />
                            </button>
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

      {/* ── Modals ── */}
      {modal?.type === "assign" && (
        <ActionModal title={`Assign Investigator — ${modal.claim.claimNumber}`} onClose={() => setModal(null)}>
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1.5">Investigator *</label>
              <select value={selectedInvestigator} onChange={e => { setSelectedInvestigator(e.target.value); setModalError(""); }}
                className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500">
                <option value="">Select investigator…</option>
                {workload.map(inv => (
                  <option key={inv.investigatorId} value={inv.investigatorId}>
                    {inv.fullName} ({inv.activeClaims} active)
                  </option>
                ))}
              </select>
            </div>
            {modalError && <p className="text-xs text-red-500 flex items-center gap-1"><AlertTriangle className="h-3 w-3" /> {modalError}</p>}
            <button onClick={handleAssign} disabled={modalLoading}
              className="w-full flex items-center justify-center gap-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-sm font-medium py-2.5 transition-colors disabled:opacity-60">
              {modalLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
              {modalLoading ? "Assigning…" : "Assign Investigator"}
            </button>
          </div>
        </ActionModal>
      )}

      {(modal?.type === "approve" || modal?.type === "reject") && (
        <ActionModal
          title={`${modal.type === "approve" ? "Approve" : "Reject"} Claim — ${modal.claim.claimNumber}`}
          onClose={() => setModal(null)}
        >
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1.5">Decision Notes *</label>
              <textarea rows={3} value={notes} onChange={e => { setNotes(e.target.value); setModalError(""); }}
                placeholder="Provide reason for this decision…"
                className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500 resize-none" />
            </div>
            {modalError && <p className="text-xs text-red-500 flex items-center gap-1"><AlertTriangle className="h-3 w-3" /> {modalError}</p>}
            <button onClick={() => handleDecision(modal.type)} disabled={modalLoading}
              className={`w-full flex items-center justify-center gap-2 rounded-lg text-white text-sm font-medium py-2.5 transition-colors disabled:opacity-60 ${
                modal.type === "approve"
                  ? "bg-slate-900 hover:bg-slate-800"
                  : "bg-red-600 hover:bg-red-700"
              }`}>
              {modalLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : modal.type === "approve" ? <CheckCircle className="h-4 w-4" /> : <XCircle className="h-4 w-4" />}
              {modalLoading ? "Processing…" : modal.type === "approve" ? "Approve Claim" : "Reject Claim"}
            </button>
          </div>
        </ActionModal>
      )}

    </DashboardLayout>
  );
}
