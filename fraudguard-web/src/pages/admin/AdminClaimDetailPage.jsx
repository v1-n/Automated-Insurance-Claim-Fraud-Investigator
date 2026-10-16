import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import {
  getInvestigatorsWorkload,
  assignInvestigator,
  approveClaim,
  rejectClaim,
  getAdminClaimById,
  getAdminClaimDocuments,
  downloadAdminDocument
} from "../../services/adminService";
import {
  ArrowLeft, FileText, MapPin, Calendar, IndianRupee,
  Loader2, AlertTriangle, CheckCircle2, Clock, XCircle,
  ShieldAlert, Tag, UserCheck, ThumbsUp, ThumbsDown, Send,
  Paperclip, Download, Info, Users,
} from "lucide-react";

// ── Helpers ────────────────────────────────────────────────────────────────
function pretty(str) {
  return str?.replace(/_/g, " ").toLowerCase().replace(/\b\w/g, c => c.toUpperCase()) || "—";
}
function fmtDateTime(raw) {
  if (!raw) return "—";
  let d;
  if (Array.isArray(raw)) {
    d = new Date(raw[0], raw[1] - 1, raw[2], raw[3] || 0, raw[4] || 0, raw[5] || 0);
  } else {
    d = new Date(raw);
  }
  if (isNaN(d.getTime())) return "—";
  return d.toLocaleString("en-IN", {
    day: "numeric", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}
function fmtAmount(n) { return `₹${Number(n).toLocaleString("en-IN")}`; }

// ── Badges ─────────────────────────────────────────────────────────────────
function StatusBadge({ status, size = "md" }) {
  const px = size === "lg" ? "px-3 py-1 text-sm" : "px-2.5 py-0.5 text-xs";
  const map = {
    APPROVED:     { cls: "bg-slate-50 text-slate-900 ring-slate-200", icon: <CheckCircle2 className="h-3.5 w-3.5" /> },
    UNDER_REVIEW: { cls: "bg-slate-50 text-slate-900 ring-slate-200", icon: <Clock className="h-3.5 w-3.5" /> },
    PENDING:      { cls: "bg-slate-50 text-slate-900 ring-slate-200", icon: <Clock className="h-3.5 w-3.5" /> },
    REJECTED:     { cls: "bg-red-50 text-red-700 ring-red-200", icon: <XCircle className="h-3.5 w-3.5" /> },
    FLAGGED:      { cls: "bg-slate-50 text-slate-900 ring-slate-200", icon: <ShieldAlert className="h-3.5 w-3.5" /> },
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-600 ring-slate-200", icon: null };
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full font-medium ring-1 ${px} ${cfg.cls}`}>
      {cfg.icon} {pretty(status)}
    </span>
  );
}

function FraudBadge({ status }) {
  const map = {
    SUSPECTED:      { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
    CONFIRMED: { cls: "bg-red-50 text-red-700 ring-red-200" },
    CLEAR:         { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-500 ring-slate-200" };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ${cfg.cls}`}>
      {status ? pretty(status) : "Unreviewed"}
    </span>
  );
}

function InfoRow({ icon, label, value }) {
  return (
    <div className="flex items-start gap-3 py-3 border-b border-slate-100 last:border-0">
      <span className="mt-0.5 text-slate-400 shrink-0">{icon}</span>
      <div className="min-w-0 flex-1">
        <p className="text-xs font-medium uppercase tracking-wide text-slate-400 mb-0.5">{label}</p>
        <p className="text-sm text-slate-800 break-words">{value}</p>
      </div>
    </div>
  );
}

// ── Main ──────────────────────────────────────────────────────────────────
export default function AdminClaimDetailPage() {
  const { claimId } = useParams();
  const navigate = useNavigate();

  const [claim, setClaim] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // investigators
  const [investigators, setInvestigators] = useState([]);
  const [selectedInv, setSelectedInv] = useState("");
  const [assigning, setAssigning] = useState(false);
  const [assignMsg, setAssignMsg] = useState({ type: "", text: "" });

  // approve / reject
  const [decisionNotes, setDecisionNotes] = useState("");
  const [deciding, setDeciding] = useState(false);
  const [decisionMsg, setDecisionMsg] = useState({ type: "", text: "" });

  // documents
  const [docs, setDocs] = useState([]);
  const [docsLoading, setDocsLoading] = useState(true);
  const [downloading, setDownloading] = useState(null);

  useEffect(() => { fetchAll(); }, [claimId]);

  const fetchAll = async () => {
    try {
      setLoading(true); setError("");
      const [claimRes, invRes, docsRes] = await Promise.all([
        getAdminClaimById(claimId),
        getInvestigatorsWorkload(),
        getAdminClaimDocuments(claimId).catch(() => ({ data: { data: [] } })),
      ]);
      setClaim(claimRes.data?.data || claimRes.data);
      setInvestigators(invRes.data?.data || []);
      setDocs(docsRes.data?.data || []);
    } catch (err) {
      setError(err.response?.data?.message || "Failed to load claim details.");
    } finally {
      setLoading(false);
      setDocsLoading(false);
    }
  };

  const handleAssign = async () => {
    if (!selectedInv) { setAssignMsg({ type: "error", text: "Select an investigator." }); return; }
    setAssigning(true); setAssignMsg({ type: "", text: "" });
    try {
      await assignInvestigator(claimId, Number(selectedInv));
      setAssignMsg({ type: "success", text: "Investigator assigned successfully!" });
      setSelectedInv("");
      fetchAll();
    } catch (err) {
      setAssignMsg({ type: "error", text: err.response?.data?.message || "Assignment failed." });
    } finally { setAssigning(false); }
  };

  const handleDecision = async (type) => {
    if (!decisionNotes.trim()) { setDecisionMsg({ type: "error", text: "Decision notes are required." }); return; }
    setDeciding(true); setDecisionMsg({ type: "", text: "" });
    try {
      const fn = type === "approve" ? approveClaim : rejectClaim;
      await fn(claimId, decisionNotes.trim());
      setDecisionMsg({ type: "success", text: `Claim ${type === "approve" ? "approved" : "rejected"} successfully!` });
      setDecisionNotes("");
      fetchAll();
    } catch (err) {
      setDecisionMsg({ type: "error", text: err.response?.data?.message || "Action failed." });
    } finally { setDeciding(false); }
  };

  const handleDownload = async (doc) => {
    try {
      setDownloading(doc.claimDocId);
      const res = await downloadAdminDocument(doc.claimDocId);
      const url = URL.createObjectURL(new Blob([res.data]));
      const a = document.createElement("a");
      a.href = url; a.download = doc.originalFileName || `doc-${doc.claimDocId}`; a.click();
      URL.revokeObjectURL(url);
    } catch { alert("Download failed."); }
    finally { setDownloading(null); }
  };

  return (
    <DashboardLayout>
      {/* Back button removed */}

      {loading ? (
        <div className="flex items-center justify-center py-24 gap-2 text-slate-400">
          <Loader2 className="h-6 w-6 animate-spin" /> <span>Loading claim…</span>
        </div>
      ) : error ? (
        <div className="flex flex-col items-center justify-center py-24 gap-3 text-red-500">
          <AlertTriangle className="h-8 w-8" />
          <p className="text-sm font-medium">{error}</p>
          <button onClick={fetchAll} className="text-xs text-slate-900 hover:underline">Retry</button>
        </div>
      ) : claim ? (
        <div className="space-y-6">

          {/* Header */}
          <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
            <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
              <div>
                <p className="text-xs font-semibold uppercase tracking-widest text-slate-400 mb-1">Claim Number</p>
                <h1 className="text-2xl font-bold text-slate-900">{claim.claimNumber || `#${claimId}`}</h1>
                <p className="text-sm text-slate-500 mt-1">Submitted on {fmtDateTime(claim.createdAt)}</p>
              </div>
              <div className="flex flex-wrap gap-2">
                <StatusBadge status={claim.claimStatus} size="lg" />
                <FraudBadge status={claim.fraudStatus} />
              </div>
            </div>
          </div>

          {/* Two-panel layout */}
          <div className="grid lg:grid-cols-2 gap-6">

            {/* LEFT — Claim details */}
            <div className="space-y-6">
              {/* Claim Info */}
              <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
                <h2 className="text-base font-semibold text-slate-800 mb-4 flex items-center gap-2">
                  <FileText className="h-4 w-4 text-slate-700" /> Claim Information
                </h2>
                <InfoRow icon={<Tag className="h-4 w-4" />} label="Claim Type" value={pretty(claim.claimType)} />
                <InfoRow icon={<IndianRupee className="h-4 w-4" />} label="Amount" value={fmtAmount(claim.claimAmount)} />
                <InfoRow icon={<FileText className="h-4 w-4" />} label="Description" value={claim.description || "—"} />
                <InfoRow icon={<Calendar className="h-4 w-4" />} label="Submitted" value={fmtDateTime(claim.createdAt)} />
                {claim.updatedAt && <InfoRow icon={<Calendar className="h-4 w-4" />} label="Updated" value={fmtDateTime(claim.updatedAt)} />}
              </div>

              {/* Incident Details */}
              <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
                <h2 className="text-base font-semibold text-slate-800 mb-4 flex items-center gap-2">
                  <MapPin className="h-4 w-4 text-slate-700" /> Incident Details
                </h2>
                <InfoRow icon={<Calendar className="h-4 w-4" />} label="Date" value={fmtDateTime(claim.incidentDate)} />
                <InfoRow icon={<MapPin className="h-4 w-4" />} label="Address" value={claim.incidentAddress || "—"} />
                <InfoRow icon={<MapPin className="h-4 w-4" />} label="City" value={claim.incidentCity || "—"} />
                <InfoRow icon={<MapPin className="h-4 w-4" />} label="State" value={claim.incidentState || "—"} />
              </div>

              {/* Documents */}
              <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
                <h2 className="text-base font-semibold text-slate-800 mb-4 flex items-center gap-2">
                  <Paperclip className="h-4 w-4 text-slate-700" /> Documents
                  {docs.length > 0 && (
                    <span className="ml-1 inline-flex items-center justify-center h-5 min-w-[20px] rounded-full bg-slate-100 text-slate-900 text-xs font-bold px-1.5">{docs.length}</span>
                  )}
                </h2>
                {docsLoading ? (
                  <div className="flex items-center gap-2 text-slate-400 py-4"><Loader2 className="h-4 w-4 animate-spin" /> Loading…</div>
                ) : docs.length === 0 ? (
                  <p className="text-sm text-slate-400 py-4">No documents uploaded.</p>
                ) : (
                  <div className="space-y-2">
                    {docs.map(doc => (
                      <div key={doc.claimDocId} className="flex items-center gap-3 rounded-lg border border-slate-100 bg-slate-50/50 px-4 py-3">
                        <FileText className="h-4 w-4 text-slate-700 shrink-0" />
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-slate-800 truncate">{doc.originalFileName}</p>
                          <p className="text-xs text-slate-400">{pretty(doc.documentType)}</p>
                        </div>
                        <button onClick={() => handleDownload(doc)} disabled={!!downloading} title="Download"
                          className="p-1.5 rounded-md text-slate-400 hover:text-slate-900 hover:bg-slate-50 transition-colors">
                          {downloading === doc.claimDocId ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* RIGHT — Admin actions */}
            <div className="space-y-6">

              {/* Assign Investigator */}
              <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
                <h2 className="text-base font-semibold text-slate-800 mb-4 flex items-center gap-2">
                  <UserCheck className="h-4 w-4 text-slate-700" /> Assign Investigator
                </h2>
                <div className="space-y-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1.5">Select Investigator *</label>
                    <select value={selectedInv} onChange={e => { setSelectedInv(e.target.value); setAssignMsg({ type: "", text: "" }); }}
                      className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500">
                      <option value="">Choose investigator…</option>
                      {investigators.map(inv => (
                        <option key={inv.investigatorId} value={inv.investigatorId}>
                          {inv.fullName} — {inv.activeClaims} active cases
                        </option>
                      ))}
                    </select>
                  </div>

                  {assignMsg.text && (
                    <p className={`text-xs flex items-center gap-1.5 ${assignMsg.type === "error" ? "text-red-600" : "text-slate-900"}`}>
                      {assignMsg.type === "error" ? <AlertTriangle className="h-3.5 w-3.5" /> : <CheckCircle2 className="h-3.5 w-3.5" />}
                      {assignMsg.text}
                    </p>
                  )}

                  <button onClick={handleAssign} disabled={assigning}
                    className="w-full flex items-center justify-center gap-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-sm font-medium py-2.5 transition-colors disabled:opacity-60 shadow-sm">
                    {assigning ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
                    {assigning ? "Assigning…" : "Assign Investigator"}
                  </button>
                </div>
              </div>

              {/* Approve / Reject */}
              <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
                <h2 className="text-base font-semibold text-slate-800 mb-4 flex items-center gap-2">
                  <Info className="h-4 w-4 text-slate-700" /> Claim Decision
                </h2>
                <div className="space-y-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1.5">Decision Notes *</label>
                    <textarea rows={4} value={decisionNotes} onChange={e => { setDecisionNotes(e.target.value); setDecisionMsg({ type: "", text: "" }); }}
                      placeholder="Provide reason for this decision…"
                      className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500 resize-none" />
                  </div>

                  {decisionMsg.text && (
                    <p className={`text-xs flex items-center gap-1.5 ${decisionMsg.type === "error" ? "text-red-600" : "text-slate-900"}`}>
                      {decisionMsg.type === "error" ? <AlertTriangle className="h-3.5 w-3.5" /> : <CheckCircle2 className="h-3.5 w-3.5" />}
                      {decisionMsg.text}
                    </p>
                  )}

                  <div className="grid grid-cols-2 gap-3">
                    <button onClick={() => handleDecision("approve")} disabled={deciding}
                      className="flex items-center justify-center gap-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-sm font-medium py-2.5 transition-colors disabled:opacity-60 shadow-sm">
                      {deciding ? <Loader2 className="h-4 w-4 animate-spin" /> : <ThumbsUp className="h-4 w-4" />}
                      Approve
                    </button>
                    <button onClick={() => handleDecision("reject")} disabled={deciding}
                      className="flex items-center justify-center gap-2 rounded-lg bg-red-600 hover:bg-red-700 text-white text-sm font-medium py-2.5 transition-colors disabled:opacity-60 shadow-sm">
                      {deciding ? <Loader2 className="h-4 w-4 animate-spin" /> : <ThumbsDown className="h-4 w-4" />}
                      Reject
                    </button>
                  </div>
                </div>
              </div>

              {/* Status Summary */}
              <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
                <h2 className="text-base font-semibold text-slate-800 mb-4 flex items-center gap-2">
                  <Info className="h-4 w-4 text-slate-700" /> Status Summary
                </h2>
                <div className="space-y-3">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-slate-500">Claim Status</span>
                    <StatusBadge status={claim.claimStatus} />
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-slate-500">Fraud Check</span>
                    <FraudBadge status={claim.fraudStatus} />
                  </div>
                  {claim.policyNumber && (
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-slate-500">Policy #</span>
                      <span className="text-slate-800 font-medium">{claim.policyNumber}</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </DashboardLayout>
  );
}
