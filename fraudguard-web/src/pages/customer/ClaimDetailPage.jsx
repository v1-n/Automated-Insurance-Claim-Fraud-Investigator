import { useEffect, useState, useRef } from "react";
import { useNavigate, useParams } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { getClaimById } from "../../services/claimService";
import {
  uploadDocument, getClaimDocuments, deleteDocument, downloadDocument,
} from "../../services/documentService";
import {
  ArrowLeft, FileText, MapPin, Calendar, IndianRupee,
  Upload, Trash2, Download, Loader2, AlertTriangle,
  CheckCircle2, Clock, XCircle, ShieldAlert, Paperclip,
  Tag, Plus, X, Info, Eye,
} from "lucide-react";

const DOCUMENT_TYPES = [
  { value: "ACCIDENT_PHOTO", label: "📷 Accident Photo" },
  { value: "FIR", label: "📋 FIR (Police Report)" },
  { value: "VEHICLE_DOCUMENT", label: "🚗 Vehicle Document" },
  { value: "POLICY_DOCUMENT", label: "📄 Policy Document" },
  { value: "MEDICAL_REPORT", label: "🏥 Medical Report" },
  { value: "REPAIR_ESTIMATE", label: "🔧 Repair Estimate" },
  { value: "INVOICE", label: "🧾 Invoice" },
  { value: "OTHER", label: "📎 Other" },
];
const ACCEPTED_MIME = "application/pdf,image/png,image/jpeg";
const MAX_MB = 10;

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
function pretty(str) {
  return str?.replace(/_/g, " ").toLowerCase().replace(/\b\w/g, c => c.toUpperCase()) || "—";
}

function StatusBadge({ status, size = "md" }) {
  const px = size === "lg" ? "px-3 py-1 text-sm" : "px-2.5 py-0.5 text-xs";
  const map = {
    APPROVED: { cls: "bg-slate-50 text-slate-900 ring-slate-200", icon: <CheckCircle2 className="h-3.5 w-3.5" /> },
    UNDER_REVIEW: { cls: "bg-slate-50 text-slate-900 ring-slate-200", icon: <Clock className="h-3.5 w-3.5" /> },
    PENDING: { cls: "bg-slate-50 text-slate-900 ring-slate-200", icon: <Clock className="h-3.5 w-3.5" /> },
    REJECTED: { cls: "bg-red-50 text-red-700 ring-red-200", icon: <XCircle className="h-3.5 w-3.5" /> },
    FLAGGED: { cls: "bg-slate-50 text-slate-900 ring-slate-200", icon: <ShieldAlert className="h-3.5 w-3.5" /> },
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
    SUSPECTED: { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
    CONFIRMED: { cls: "bg-red-50 text-red-700 ring-red-200" },
    CLEAR: { cls: "bg-slate-50 text-slate-900 ring-slate-200" },
  };
  const cfg = map[status] || { cls: "bg-slate-50 text-slate-500 ring-slate-200" };
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ${cfg.cls}`}>
      {status ? pretty(status) : "Unreviewed"}
    </span>
  );
}

function DocStatusBadge({ status }) {
  const map = {
    ACTIVE: "bg-slate-50 text-slate-900 ring-slate-200",
    SCANNING: "bg-slate-50 text-slate-900 ring-slate-200",
    INFECTED: "bg-red-50 text-red-700 ring-red-200",
    PENDING: "bg-slate-50 text-slate-900 ring-slate-200",
    DELETED: "bg-slate-50 text-slate-400 ring-slate-200",
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ${map[status] || "bg-slate-50 text-slate-600 ring-slate-200"}`}>
      {pretty(status)}
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

// ── Document Section (list + upload) ───────────────────────────────────────
function DocumentSection({ claimId, claimStatus }) {
  const [docs, setDocs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [deleting, setDeleting] = useState(null);
  const [downloading, setDownloading] = useState(null);
  const [showUpload, setShowUpload] = useState(false);
  const [docType, setDocType] = useState("");
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [uploadErr, setUploadErr] = useState("");
  const [uploadOk, setUploadOk] = useState(false);
  const [viewingDoc, setViewingDoc] = useState(null);
  const fileRef = useRef();

  useEffect(() => { fetchDocs(); }, [claimId]);

  const fetchDocs = async () => {
    try { setLoading(true); setError("");
      const res = await getClaimDocuments(claimId);
      setDocs(res.data?.data || []);
    } catch { setError("Failed to load documents."); }
    finally { setLoading(false); }
  };

  const handleDelete = async (docId) => {
    if (!window.confirm("Delete this document?")) return;
    try { setDeleting(docId); await deleteDocument(docId);
      setDocs(prev => prev.filter(d => d.claimDocId !== docId));
    } catch { alert("Failed to delete document."); }
    finally { setDeleting(null); }
  };

  const handleDownload = async (doc) => {
    try { setDownloading(doc.claimDocId);
      const res = await downloadDocument(doc.claimDocId);
      const url = URL.createObjectURL(new Blob([res.data]));
      const a = document.createElement("a");
      a.href = url; a.download = doc.originalFileName || `document-${doc.claimDocId}`; a.click();
      URL.revokeObjectURL(url);
    } catch { alert("Failed to download document."); }
    finally { setDownloading(null); }
  };

  const handleView = async (doc) => {
    try { 
      setDownloading(doc.claimDocId);
      const res = await downloadDocument(doc.claimDocId);
      // Determine content type; fallback to application/pdf
      const contentType = res.headers['content-type'] || doc.mimeType || 'application/pdf';
      const url = URL.createObjectURL(new Blob([res.data], { type: contentType }));
      setViewingDoc({ url, type: contentType, name: doc.originalFileName || `Document #${doc.claimDocId}` });
    } catch { 
      alert("Failed to load document for viewing."); 
    } finally { 
      setDownloading(null); 
    }
  };

  const handleFile = (e) => {
    const f = e.target.files[0]; setUploadErr(""); setUploadOk(false);
    if (!f) return;
    if (f.size > MAX_MB * 1024 * 1024) { setUploadErr(`File too large — max ${MAX_MB} MB.`); return; }
    setFile(f);
  };

  const handleUpload = async () => {
    if (!docType) { setUploadErr("Please select a document type."); return; }
    if (!file) { setUploadErr("Please choose a file."); return; }
    try { setUploading(true); setUploadErr("");
      await uploadDocument(claimId, file, docType);
      setUploadOk(true); setFile(null); setDocType("");
      if (fileRef.current) fileRef.current.value = "";
      fetchDocs();
      setTimeout(() => { setUploadOk(false); }, 3000);
    } catch (err) { setUploadErr(err.response?.data?.message || "Upload failed."); }
    finally { setUploading(false); }
  };

  return (
    <>
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-base font-semibold text-slate-800 flex items-center gap-2">
            <Paperclip className="h-4 w-4 text-slate-700" /> Documents
            {docs.length > 0 && (
              <span className="ml-1 inline-flex items-center justify-center h-5 min-w-[20px] rounded-full bg-slate-100 text-slate-900 text-xs font-bold px-1.5">
                {docs.length}
              </span>
            )}
          </h2>
          {claimStatus !== "REJECTED" && (
            <button
              onClick={() => setShowUpload(!showUpload)}
              className={`flex items-center gap-1.5 rounded-lg text-sm font-medium px-3 py-1.5 transition-all ${
                showUpload
                  ? "bg-slate-100 text-slate-600 hover:bg-slate-200"
                  : "bg-slate-900 text-white hover:bg-slate-800 shadow-sm"
              }`}
            >
              {showUpload ? <X className="h-3.5 w-3.5" /> : <Plus className="h-3.5 w-3.5" />}
              {showUpload ? "Cancel" : "Upload More"}
            </button>
          )}
        </div>

        {/* Upload panel (toggled) */}
        {showUpload && (
          <div className="rounded-xl border border-dashed border-slate-300 bg-slate-50/50 p-4 mb-5 space-y-3 animate-in">
            <div className="grid sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-slate-500 mb-1.5">Document Type *</label>
                <select value={docType} onChange={e => { setDocType(e.target.value); setUploadErr(""); setUploadOk(false); }}
                  className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500">
                  <option value="">Select type…</option>
                  {DOCUMENT_TYPES.map(d => <option key={d.value} value={d.value}>{d.label}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-500 mb-1.5">File (PDF / PNG / JPG) *</label>
                <input ref={fileRef} type="file" accept={ACCEPTED_MIME} onChange={handleFile}
                  className="w-full text-sm text-slate-600 file:mr-3 file:rounded-md file:border-0 file:bg-slate-50 file:text-slate-900 file:text-xs file:font-medium file:px-3 file:py-1.5 file:cursor-pointer hover:file:bg-slate-100 cursor-pointer" />
                {file && <p className="text-xs text-slate-400 mt-1 truncate">{file.name} ({(file.size / 1024).toFixed(1)} KB)</p>}
              </div>
            </div>
            {uploadErr && <p className="text-xs text-red-600 flex items-center gap-1.5"><AlertTriangle className="h-3.5 w-3.5" /> {uploadErr}</p>}
            {uploadOk && <p className="text-xs text-slate-900 flex items-center gap-1.5"><CheckCircle2 className="h-3.5 w-3.5" /> Uploaded successfully!</p>}
            <button onClick={handleUpload} disabled={uploading}
              className="flex items-center gap-2 rounded-lg bg-slate-900 hover:bg-slate-800 disabled:opacity-60 text-white text-sm font-medium px-4 py-2 transition-colors shadow-sm">
              {uploading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
              {uploading ? "Uploading…" : "Upload Document"}
            </button>
          </div>
        )}

        {/* Document list */}
        {loading ? (
          <div className="flex items-center gap-2 text-slate-400 py-6 justify-center">
            <Loader2 className="h-4 w-4 animate-spin" /> <span className="text-sm">Loading documents…</span>
          </div>
        ) : error ? (
          <div className="flex items-center gap-2 text-red-500 py-4">
            <AlertTriangle className="h-4 w-4" /> <span className="text-sm">{error}</span>
            <button onClick={fetchDocs} className="text-xs text-slate-900 hover:underline ml-1">Retry</button>
          </div>
        ) : docs.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-10 text-slate-400">
            <Paperclip className="h-8 w-8 mb-2 text-slate-300" />
            <p className="text-sm">No documents uploaded yet</p>
            <p className="text-xs mt-1">Click "Upload More" to add documents</p>
          </div>
        ) : (
          <div className="space-y-3">
            {docs.map(doc => (
              <div key={doc.claimDocId} className="flex flex-col sm:flex-row sm:items-center justify-between rounded-lg border border-slate-100 bg-white px-4 py-3 shadow-sm transition-all gap-4">
                <div className="flex items-center gap-3">
                  <div className="h-8 w-8 rounded bg-slate-50 flex items-center justify-center shrink-0">
                    <Paperclip className="h-4 w-4 text-slate-700" />
                  </div>
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-slate-800 truncate">{doc.originalFileName || `Document #${doc.claimDocId}`}</p>
                    <p className="text-xs text-slate-400 mt-0.5">
                      {doc.fileSize ? `${(doc.fileSize / 1024 / 1024).toFixed(1)} MB` : "File size unknown"} • {fmtDateTime(doc.uploadedAt)}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-1.5 shrink-0">
                  <button onClick={() => handleView(doc)} disabled={!!downloading} title="View Document"
                    className="p-2 rounded-lg text-slate-400 hover:text-slate-900 hover:bg-slate-100 transition-colors"
                  >
                    {downloading === doc.claimDocId ? <Loader2 className="h-4 w-4 animate-spin" /> : <Eye className="h-4 w-4" />}
                  </button>
                  <button onClick={() => handleDownload(doc)} disabled={!!downloading} title="Download Document"
                    className="p-2 rounded-lg text-slate-400 hover:text-slate-900 hover:bg-slate-100 transition-colors"
                  >
                    {downloading === doc.claimDocId ? <Loader2 className="h-4 w-4 animate-spin" /> : <Download className="h-4 w-4" />}
                  </button>
                  <button onClick={() => handleDelete(doc.claimDocId)} disabled={!!deleting} title="Delete Document"
                    className="p-2 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                  >
                    {deleting === doc.claimDocId ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
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
    </>
  );
}

// ── Main page ──────────────────────────────────────────────────────────────
export default function ClaimDetailPage() {
  const { claimId } = useParams();
  const navigate = useNavigate();
  const [claim, setClaim] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => { fetchClaim(); }, [claimId]);

  const fetchClaim = async () => {
    try { setLoading(true); setError("");
      const res = await getClaimById(claimId);
      setClaim(res.data?.data || res.data);
    } catch (err) { setError(err.response?.data?.message || "Failed to load claim details."); }
    finally { setLoading(false); }
  };

  return (
    <DashboardLayout>
      {loading ? (
        <div className="flex items-center justify-center py-24 gap-2 text-slate-400">
          <Loader2 className="h-6 w-6 animate-spin" /> <span>Loading claim…</span>
        </div>
      ) : error ? (
        <div className="flex flex-col items-center justify-center py-24 gap-3 text-red-500">
          <AlertTriangle className="h-8 w-8" />
          <p className="text-sm font-medium">{error}</p>
          <button onClick={fetchClaim} className="text-xs text-slate-900 hover:underline">Retry</button>
        </div>
      ) : claim ? (
        <div className="space-y-6 mt-4">
          {/* Header */}
          <div className="mb-6">
            <div className="flex items-center gap-3 mb-1">
              <h1 className="text-xl font-bold text-slate-900">{claim.claimNumber || `#${claimId}`}</h1>
              <StatusBadge status={claim.claimStatus} />
              <FraudBadge status={claim.fraudStatus} />
            </div>
            <p className="text-sm text-slate-500">
              {pretty(claim.claimType)} • Submitted {fmtDateTime(claim.createdAt)}
            </p>
          </div>

          {/* Grid Layout */}
          <div className="grid lg:grid-cols-3 gap-6">
            {/* LEFT: Claim Information & Documents */}
            <div className="lg:col-span-2 space-y-6">
              
              {/* Claim Info Card */}
              <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
                <h2 className="text-base font-semibold text-slate-800 mb-6 flex items-center gap-2">
                  <FileText className="h-4 w-4 text-slate-700" /> Claim Information
                </h2>
                <div className="grid sm:grid-cols-2 gap-6">
                  {/* Left Column */}
                  <div className="space-y-5">
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Claim Type</p>
                      <p className="text-sm text-slate-800">{pretty(claim.claimType)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Incident Date</p>
                      <p className="text-sm text-slate-800">{fmtDateTime(claim.incidentDate)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1 flex items-center gap-1">
                        <MapPin className="h-3 w-3" /> Incident Location
                      </p>
                      <p className="text-sm text-slate-800">{[claim.incidentAddress, claim.incidentCity, claim.incidentState].filter(Boolean).join(", ") || "—"}</p>
                    </div>
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Description</p>
                      <p className="text-sm text-slate-800">{claim.description || "—"}</p>
                    </div>
                  </div>
                  {/* Right Column */}
                  <div className="space-y-5">
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Claim Amount</p>
                      <p className="text-sm font-semibold text-slate-900">{fmtAmount(claim.claimAmount)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-slate-400 font-medium mb-1">Submitted</p>
                      <p className="text-sm text-slate-800">{fmtDateTime(claim.createdAt)}</p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Documents Card */}
              <div>
                <DocumentSection claimId={claimId} claimStatus={claim.claimStatus} />
              </div>
            </div>

            {/* RIGHT: Fraud Status Sidebar */}
            <div className="space-y-6">
              <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
                <h2 className="text-base font-semibold text-slate-800 mb-6 flex items-center gap-2">
                  <ShieldAlert className="h-4 w-4 text-slate-700" /> Fraud Status
                </h2>
                <div className="space-y-4">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-slate-500">Claim Status</span>
                    <StatusBadge status={claim.claimStatus} />
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-slate-500">Fraud Status</span>
                    <FraudBadge status={claim.fraudStatus} />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </DashboardLayout>
  );
}
