import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { getClaimDetails, reviewClaim, viewDocument } from "../../services/investigatorService";
import { getUser } from "../../utils/auth";
import {
  ArrowLeft, FileText, MapPin, Loader2, AlertTriangle,
  CheckCircle2, ShieldAlert, Paperclip, UserCircle, X, Eye
} from "lucide-react";

// formatters
function fmtDateTime(raw) {
  if (!raw) return "—";
  let d;
  if (Array.isArray(raw)) {
    d = new Date(raw[0], raw[1] - 1, raw[2], raw[3] || 0, raw[4] || 0, raw[5] || 0);
  } else {
    d = new Date(raw);
  }
  if (isNaN(d.getTime())) return "—";
  return d.toLocaleString("en-US");
}
function fmtAmount(n) { return `$${Number(n).toLocaleString("en-US")}`; }
function pretty(str) {
  return str?.replace(/_/g, " ").toLowerCase().replace(/\b\w/g, c => c.toUpperCase()) || "—";
}
function formatDateOnly(raw) {
  if (!raw) return "—";
  let d;
  if (Array.isArray(raw)) {
    d = new Date(raw[0], raw[1] - 1, raw[2]);
  } else {
    d = new Date(raw);
  }
  if (isNaN(d.getTime())) return "—";
  return d.toISOString().split('T')[0];
}

// badges
function StatusBadge({ status }) {
  const map = {
    APPROVED: "bg-emerald-50 text-emerald-700 ring-emerald-200",
    UNDER_REVIEW: "bg-amber-50 text-amber-700 ring-amber-200",
    PENDING: "bg-slate-50 text-slate-700 ring-slate-200",
    REJECTED: "bg-red-50 text-red-700 ring-red-200",
    FLAGGED: "bg-amber-50 text-amber-700 ring-amber-200",
  };
  const cls = map[status] || "bg-slate-50 text-slate-600 ring-slate-200";
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-semibold tracking-wider uppercase ring-1 ${cls}`}>
      {status ? status.replace(/_/g, " ") : "UNKNOWN"}
    </span>
  );
}

function FraudBadge({ status }) {
  const map = {
    SUSPECTED: "bg-amber-50 text-amber-700 ring-amber-200",
    CONFIRMED: "bg-red-50 text-red-700 ring-red-200",
    CLEAR: "bg-emerald-50 text-emerald-700 ring-emerald-200",
    PENDING_ANALYSIS: "bg-slate-50 text-slate-700 ring-slate-200"
  };
  const cls = map[status] || "bg-slate-50 text-slate-500 ring-slate-200";
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-semibold tracking-wider uppercase ring-1 ${cls}`}>
      {status ? status.replace(/_/g, " ") : "CLEAR"}
    </span>
  );
}

export default function InvestigatorClaimDetailPage() {
  const { claimId } = useParams();
  const navigate = useNavigate();
  const user = getUser();
  const [claim, setClaim] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Review state
  const [reviewNotes, setReviewNotes] = useState("");
  const [fraudStatus, setFraudStatus] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [submitSuccess, setSubmitSuccess] = useState(false);

  // Document view state
  const [downloading, setDownloading] = useState(null);
  const [viewingDoc, setViewingDoc] = useState(null);

  useEffect(() => {
    fetchClaim();
  }, [claimId]);

  const fetchClaim = async () => {
    try {
      setLoading(true); setError("");
      const res = await getClaimDetails(claimId);
      const data = res.data?.data || res.data;
      setClaim(data);
      setReviewNotes(data.reviewNotes || "");
      setFraudStatus(data.fraudStatus === "PENDING_ANALYSIS" ? "CLEAR" : (data.fraudStatus || "CLEAR"));
    } catch (err) {
      setError(err.response?.data?.message || "Failed to load claim details.");
    } finally {
      setLoading(false);
    }
  };

  const handleReviewSubmit = async () => {
    if (!reviewNotes.trim()) { setSubmitError("Review notes are required"); return; }
    if (!fraudStatus) { setSubmitError("Fraud status is required"); return; }
    try {
      setSubmitting(true); setSubmitError(""); setSubmitSuccess(false);
      await reviewClaim(claimId, { reviewNotes, fraudStatus });
      setSubmitSuccess(true);
      setTimeout(() => {
        navigate("/investigator/dashboard");
      }, 2000);
    } catch (err) {
      setSubmitError(err.response?.data?.message || "Failed to submit review.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleView = async (doc) => {
    try {
      setDownloading(doc.documentId);
      const res = await viewDocument(doc.documentId);
      const contentType = res.headers['content-type'] || 'application/pdf';
      const url = URL.createObjectURL(new Blob([res.data], { type: contentType }));
      setViewingDoc({ url, type: contentType, name: doc.fileName || `Document #${doc.documentId}` });
    } catch {
      alert("Failed to load document for viewing.");
    } finally {
      setDownloading(null);
    }
  };

  if (loading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center py-24 gap-2 text-slate-400">
          <Loader2 className="h-6 w-6 animate-spin" /> <span>Loading claim…</span>
        </div>
      </DashboardLayout>
    );
  }

  if (error || !claim) {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center py-24 gap-3 text-red-500">
          <AlertTriangle className="h-8 w-8" />
          <p className="text-sm font-medium">{error}</p>
          <button onClick={fetchClaim} className="text-xs text-slate-900 hover:underline">Retry</button>
        </div>
      </DashboardLayout>
    );
  }

  const getInitials = (name) => {
    if (!name) return "??";
    return name.split(" ").map(n => n[0]).join("").toUpperCase().substring(0, 2);
  };

  const showRightPanel = claim && (claim.reviewAllowed || claim.reviewNotes);

  return (
    <DashboardLayout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <div className="flex items-center gap-3 mb-1">
            <h1 className="text-2xl font-bold text-slate-900">{claim.claimNumber}</h1>
            <StatusBadge status={claim.claimStatus} />
            <FraudBadge status={claim.fraudStatus} />
          </div>
          <p className="text-sm text-slate-500">
            Review and assess this claim
          </p>
        </div>

        <div className={showRightPanel ? "grid lg:grid-cols-3 gap-6 items-start" : "space-y-6"}>

          {/* Left Column (Information & Docs) */}
          <div className={showRightPanel ? "lg:col-span-2 space-y-6" : "space-y-6"}>

            {/* Claim Information */}
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-6 py-4 border-b border-slate-100 flex items-center gap-2 bg-slate-50/50">
                <FileText className="h-4 w-4 text-slate-700" />
                <h3 className="text-sm font-bold text-slate-900">Claim Information</h3>
              </div>
              <div className="p-6">
                <div className="grid sm:grid-cols-2 gap-6 mb-6">
                  <div className="space-y-5">
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Claim Type</p>
                      <p className="text-sm text-slate-800">{pretty(claim.claimType)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Incident Date</p>
                      <p className="text-sm text-slate-800">{fmtDateTime(claim.incidentDate)}</p>
                    </div>
                  </div>
                  <div className="space-y-5">
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Claim Amount</p>
                      <p className="text-sm font-bold text-slate-900">{fmtAmount(claim.claimAmount)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Submitted</p>
                      <p className="text-sm text-slate-800">{fmtDateTime(claim.createdAt)}</p>
                    </div>
                  </div>
                </div>

                <div className="space-y-5">
                  <div>
                    <p className="text-xs text-slate-400 font-medium mb-1 flex items-center gap-1">
                      <MapPin className="h-3 w-3" /> Location
                    </p>
                    <p className="text-sm text-slate-800">{[claim.incidentCity, claim.incidentState].filter(Boolean).join(", ") || "—"}</p>
                  </div>
                  <div>
                    <p className="text-xs text-slate-400 font-medium mb-1">Description</p>
                    <p className="text-sm text-slate-800">{claim.description || "—"}</p>
                  </div>
                </div>
              </div>
            </div>

            {/* Customer Information */}
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-6 py-4 border-b border-slate-100 flex items-center gap-2 bg-slate-50/50">
                <UserCircle className="h-4 w-4 text-slate-700" />
                <h3 className="text-sm font-bold text-slate-900">Customer Information</h3>
              </div>
              <div className="p-6 flex items-center gap-4">
                <div className="h-12 w-12 rounded-full bg-blue-50 text-blue-600 flex items-center justify-center font-bold text-lg">
                  {getInitials(claim.customerName)}
                </div>
                <div>
                  <p className="text-sm font-bold text-slate-900">{claim.customerName}</p>
                  <p className="text-xs text-slate-500">{claim.customerEmail}</p>
                </div>
              </div>
            </div>

            {/* Uploaded Documents */}
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div className="px-6 py-4 border-b border-slate-100 flex items-center gap-2 bg-slate-50/50">
                <Paperclip className="h-4 w-4 text-slate-700" />
                <h3 className="text-sm font-bold text-slate-900">Uploaded Documents ({claim.documents?.length || 0})</h3>
              </div>
              <div className="p-6">
                {claim.documents && claim.documents.length > 0 ? (
                  <div className="space-y-3">
                    {claim.documents.map(doc => (
                      <div key={doc.documentId} className="flex items-center justify-between p-4 border border-slate-100 rounded-lg bg-white shadow-sm transition-all hover:border-slate-200">
                        <div className="flex items-center gap-3">
                          <div className="h-8 w-8 rounded bg-slate-50 flex items-center justify-center shrink-0">
                            <Paperclip className="h-4 w-4 text-blue-500" />
                          </div>
                          <div>
                            <p className="text-sm font-medium text-slate-900">{doc.fileName}</p>
                            <p className="text-xs text-slate-500">{pretty(doc.documentType)}</p>
                          </div>
                        </div>
                        <button
                          onClick={() => handleView(doc)}
                          disabled={downloading === doc.documentId}
                          className="flex items-center gap-1 text-xs font-medium text-slate-700 hover:text-slate-900 px-3 py-1.5 transition-colors"
                        >
                          {downloading === doc.documentId ? <Loader2 className="h-3 w-3 animate-spin" /> : null}
                          View
                        </button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="flex flex-col items-center justify-center py-6 text-slate-400">
                    <Paperclip className="h-6 w-6 mb-2 text-slate-300" />
                    <p className="text-sm">No documents uploaded</p>
                  </div>
                )}
              </div>
            </div>

          </div>

          {/* Right Column (Submit Review / Investigation Review) */}
          {claim.reviewAllowed ? (
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden sticky top-6">
              <div className="px-6 py-4 border-b border-slate-100 flex items-center gap-2 bg-slate-50/50">
                <CheckCircle2 className="h-4 w-4 text-slate-700" />
                <h3 className="text-sm font-bold text-slate-900">Submit Review</h3>
              </div>
              <div className="p-6 space-y-6">

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-2">Review Notes <span className="text-red-500">*</span></label>
                  <textarea
                    rows={4}
                    className="w-full bg-slate-50 border border-slate-200 rounded-lg p-3 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-300 transition-colors placeholder:text-slate-400 resize-none"
                    placeholder="Document your investigation findings, discrepancies found, evidence reviewed..."
                    value={reviewNotes}
                    onChange={e => { setReviewNotes(e.target.value); setSubmitError(""); }}
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-2">Fraud Status <span className="text-red-500">*</span></label>
                  <div className="space-y-3">
                    {[
                      { val: "CLEAR", title: "Clear", sub: "No signs of fraudulent activity" },
                      { val: "SUSPECTED", title: "Suspected", sub: "Inconsistencies found, further review needed" },
                      { val: "CONFIRMED", title: "Confirmed Fraud", sub: "Clear evidence of fraudulent activity" }
                    ].map(opt => (
                      <label key={opt.val} className={`flex items-start gap-3 p-4 rounded-lg border cursor-pointer transition-colors ${fraudStatus === opt.val ? 'border-slate-900 bg-slate-50/50' : 'border-slate-200 hover:bg-slate-50 hover:border-slate-300'}`}>
                        <input
                          type="radio"
                          name="fraudStatus"
                          value={opt.val}
                          checked={fraudStatus === opt.val}
                          onChange={() => { setFraudStatus(opt.val); setSubmitError(""); }}
                          className="mt-0.5 w-4 h-4 text-slate-900 border-slate-300 focus:ring-slate-900"
                        />
                        <div className="flex-1">
                          <p className={`text-sm font-semibold ${fraudStatus === opt.val ? 'text-slate-900' : 'text-slate-700'}`}>{opt.title}</p>
                          <p className="text-xs text-slate-500 mt-0.5">{opt.sub}</p>
                        </div>
                      </label>
                    ))}
                  </div>
                </div>

                {submitError && <p className="text-xs text-red-600 font-medium flex items-center gap-1.5"><AlertTriangle className="h-3.5 w-3.5" /> {submitError}</p>}
                {submitSuccess && <p className="text-xs text-emerald-600 font-medium flex items-center gap-1.5"><CheckCircle2 className="h-3.5 w-3.5" /> Review submitted successfully!</p>}

                <button
                  onClick={handleReviewSubmit}
                  disabled={submitting || submitSuccess}
                  className="w-full py-3 bg-slate-900 text-white rounded-lg text-sm font-bold tracking-wide hover:bg-slate-800 transition-colors disabled:opacity-60 flex items-center justify-center gap-2 shadow-sm"
                >
                  {submitting ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
                  {submitting ? "Submitting..." : "Submit Review"}
                </button>
              </div>
            </div>
          ) : claim.reviewNotes ? (
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden sticky top-6">
              <div className="px-6 py-4 border-b border-slate-100 flex items-center gap-2 bg-slate-50/50">
                <CheckCircle2 className="h-4 w-4 text-slate-700" />
                <h3 className="text-sm font-bold text-slate-900">Investigation Review</h3>
              </div>
              <div className="p-6 space-y-5">
                <div>
                  <p className="text-xs text-slate-400 font-bold uppercase tracking-wider mb-2">Fraud Status</p>
                  <FraudBadge status={claim.fraudStatus} />
                </div>
                <div>
                  <p className="text-xs text-slate-400 font-bold uppercase tracking-wider mb-2">Review Notes</p>
                  <p className="text-sm text-slate-800 bg-slate-50 border border-slate-100 rounded-lg p-3 whitespace-pre-wrap leading-relaxed">
                    {claim.reviewNotes}
                  </p>
                </div>
                {user && (
                  <div>
                    <p className="text-xs text-slate-400 font-bold uppercase tracking-wider mb-1">Reviewed By</p>
                    <p className="text-sm font-medium text-slate-800">{user.fullName}</p>
                  </div>
                )}
                <div>
                  <p className="text-xs text-slate-400 font-bold uppercase tracking-wider mb-1">Reviewed On</p>
                  <p className="text-sm font-medium text-slate-800">{formatDateOnly(claim.updatedAt)}</p>
                </div>
              </div>
            </div>
          ) : null}

        </div>

      </div>

      {/* Inline Document Viewer Modal */}
      {viewingDoc && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/60 p-4 backdrop-blur-sm">
          <div className="flex h-full max-h-[90vh] w-full max-w-5xl flex-col overflow-hidden rounded-xl bg-white shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
              <h3 className="text-lg font-semibold text-slate-800">{viewingDoc.name}</h3>
              <button
                onClick={() => { URL.revokeObjectURL(viewingDoc.url); setViewingDoc(null); }}
                className="rounded-lg p-2 text-slate-400 hover:bg-slate-100 hover:text-slate-900 transition-colors"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            <div className="flex-1 bg-slate-100 p-4 overflow-hidden">
              {viewingDoc.type?.startsWith("image/") ? (
                <div className="flex h-full w-full items-center justify-center">
                  <img src={viewingDoc.url} alt={viewingDoc.name} className="h-full w-full rounded shadow-sm object-contain" />
                </div>
              ) : (
                <iframe src={viewingDoc.url} className="h-full w-full rounded border border-slate-200 bg-white shadow-sm" title={viewingDoc.name} />
              )}
            </div>
          </div>
        </div>
      )}
    </DashboardLayout>
  );
}