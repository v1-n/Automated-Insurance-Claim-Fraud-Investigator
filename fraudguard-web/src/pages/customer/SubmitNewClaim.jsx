import { useState, useRef } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { addClaim } from "../../services/claimService";
import { uploadDocument, deleteDocument, downloadDocument } from "../../services/documentService";
import {
  FileText, ArrowLeft, CheckCircle2, Loader2, AlertCircle,
  Calendar, MapPin, IndianRupee, AlignLeft, Upload, Trash2,
  Download, Paperclip, X,
} from "lucide-react";

const CLAIM_TYPES = [
  { value: "CAR", label: "🚗  Car" },
  { value: "BIKE", label: "🏍️  Bike" },
  { value: "TRUCK", label: "🚛  Truck" },
  { value: "OTHER", label: "📋  Other" },
];

const DOCUMENT_TYPES = [
  { value: "ACCIDENT_PHOTO", label: "Accident Photo" },
  { value: "FIR", label: "FIR (Police Report)" },
  { value: "VEHICLE_DOCUMENT", label: "Vehicle Document (RC/DL)" },
  { value: "POLICY_DOCUMENT", label: "Policy Document" },
  { value: "MEDICAL_REPORT", label: "Medical Report" },
  { value: "REPAIR_ESTIMATE", label: "Repair Estimate" },
  { value: "INVOICE", label: "Invoice" },
  { value: "OTHER", label: "Other" },
];

const ACCEPTED_MIME = ["application/pdf", "image/png", "image/jpeg"];
const ACCEPTED_EXT = ".pdf,.png,.jpg,.jpeg";

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function DocStatusBadge({ status }) {
  const map = {
    ACTIVE: "bg-slate-50 text-slate-900 ring-slate-200",
    SCANNING: "bg-slate-50 text-slate-900 ring-slate-200",
    PENDING: "bg-slate-50 text-slate-900 ring-slate-200",
    INFECTED: "bg-red-50 text-red-700 ring-red-200",
    DELETED: "bg-slate-50 text-slate-500 ring-slate-200",
  };
  return (
    <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium ring-1 ${map[status] || map.PENDING}`}>
      {status}
    </span>
  );
}

function Field({ label, required, error, hint, children }) {
  return (
    <div>
      <label className="block text-xs font-semibold text-slate-600 uppercase tracking-wide mb-1.5">
        {label} {required && <span className="text-red-500">*</span>}
      </label>
      {children}
      {error ? (
        <p className="mt-1.5 flex items-center gap-1 text-xs text-red-500">
          <AlertCircle className="h-3 w-3 shrink-0" /> {error}
        </p>
      ) : hint ? (
        <p className="mt-1.5 text-xs text-slate-400">{hint}</p>
      ) : null}
    </div>
  );
}

const inputCls = (err) =>
  [
    "w-full rounded-lg border px-3.5 py-2.5 text-sm text-slate-800 bg-white outline-none transition-all",
    "placeholder:text-slate-400",
    "focus:ring-2 focus:ring-slate-500/20 focus:border-slate-500",
    err
      ? "border-red-300 bg-red-50/40 focus:ring-red-500/20 focus:border-red-400"
      : "border-slate-200 hover:border-slate-300",
  ].join(" ");

const EMPTY_FORM = {
  claimType: "", claimAmount: "", description: "",
  incidentDate: "", incidentAddress: "", incidentCity: "", incidentState: "",
};

// ── Document upload panel (shown on success screen) ───────────────────────
function DocumentUploader({ claimId }) {
  const fileInputRef = useRef(null);
  const [docType, setDocType] = useState("");
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [uploadErr, setUploadErr] = useState("");
  const [documents, setDocuments] = useState([]);
  const [deletingId, setDeletingId] = useState(null);

  const handleFileChange = (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    if (!ACCEPTED_MIME.includes(f.type)) {
      setUploadErr("Only PDF, PNG, JPG, JPEG files are allowed.");
      return;
    }
    setUploadErr("");
    setFile(f);
  };

  const handleUpload = async () => {
    if (!docType) { setUploadErr("Please select a document type."); return; }
    if (!file) { setUploadErr("Please choose a file to upload."); return; }
    setUploadErr("");
    setUploading(true);
    try {
      const res = await uploadDocument(claimId, file, docType);
      const doc = res.data?.data;
      setDocuments((prev) => [doc, ...prev]);
      setFile(null);
      setDocType("");
      if (fileInputRef.current) fileInputRef.current.value = "";
    } catch (err) {
      setUploadErr(err.response?.data?.message || "Upload failed. Please try again.");
    } finally {
      setUploading(false);
    }
  };

  const handleDelete = async (documentId) => {
    setDeletingId(documentId);
    try {
      await deleteDocument(documentId);
      setDocuments((prev) => prev.filter((d) => d.claimDocId !== documentId));
    } catch (err) {
      console.error("Delete failed:", err);
    } finally {
      setDeletingId(null);
    }
  };

  const handleDownload = async (doc) => {
    try {
      const res = await downloadDocument(doc.claimDocId);
      const url = window.URL.createObjectURL(new Blob([res.data]));
      const a = document.createElement("a");
      a.href = url;
      a.download = doc.originalFileName;
      a.click();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error("Download failed:", err);
    }
  };

  return (
    <div className="space-y-4">
      {/* Upload row */}
      <div className="bg-white border border-slate-200 rounded-xl p-4 space-y-3 shadow-sm">
        <div className="flex items-center gap-2 mb-1">
          <Paperclip className="h-4 w-4 text-slate-900" />
          <h3 className="text-sm font-semibold text-slate-800">Upload Supporting Documents</h3>
          <span className="text-xs text-slate-400">(PDF, PNG, JPG)</span>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <select value={docType} onChange={(e) => { setDocType(e.target.value); setUploadErr(""); }}
            className={inputCls(!docType && uploadErr)}>
            <option value="">Select type…</option>
            {DOCUMENT_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
          </select>
          <div className="relative">
            <input ref={fileInputRef} type="file" accept={ACCEPTED_EXT} onChange={handleFileChange}
              className="absolute inset-0 opacity-0 cursor-pointer z-10" />
            <div className={`flex items-center gap-2 rounded-lg border px-3 py-2.5 text-sm transition-all cursor-pointer ${file ? "border-slate-300 bg-slate-50 text-slate-900" : "border-slate-200 text-slate-400 hover:border-slate-300 bg-white"}`}>
              <Upload className="h-4 w-4 shrink-0" />
              <span className="truncate">{file ? file.name : "Choose file…"}</span>
              {file && (
                <button type="button" onClick={(e) => { e.stopPropagation(); setFile(null); if (fileInputRef.current) fileInputRef.current.value = ""; }}
                  className="ml-auto shrink-0 text-slate-400 hover:text-red-500 z-20 relative">
                  <X className="h-3.5 w-3.5" />
                </button>
              )}
            </div>
          </div>
        </div>
        {uploadErr && <p className="flex items-center gap-1 text-xs text-red-500"><AlertCircle className="h-3 w-3 shrink-0" /> {uploadErr}</p>}
        {file && <p className="text-xs text-slate-400">{file.name} · {formatBytes(file.size)}</p>}
        <button type="button" onClick={handleUpload} disabled={uploading}
          className="w-full flex items-center justify-center gap-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-sm font-medium py-2 transition-colors disabled:opacity-60 disabled:cursor-not-allowed">
          {uploading ? <><Loader2 className="h-4 w-4 animate-spin" /> Uploading…</> : <><Upload className="h-4 w-4" /> Upload Document</>}
        </button>
      </div>

      {/* Uploaded documents list */}
      {documents.length > 0 && (
        <div className="space-y-2">
          <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Uploaded ({documents.length})</p>
          {documents.map((doc) => (
            <div key={doc.claimDocId} className="flex items-center gap-3 bg-white border border-slate-200 rounded-xl px-4 py-3 shadow-sm">
              <FileText className="h-5 w-5 text-slate-700 shrink-0" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-slate-800 truncate">{doc.originalFileName}</p>
                <div className="flex items-center gap-2 mt-0.5">
                  <span className="text-xs text-slate-400">{doc.documentType?.replace(/_/g, " ")}</span>
                  <span className="text-slate-300">·</span>
                  <span className="text-xs text-slate-400">{formatBytes(doc.fileSize || 0)}</span>
                  <DocStatusBadge status={doc.documentStatus} />
                </div>
              </div>
              <div className="flex items-center gap-1 shrink-0">
                <button type="button" onClick={() => handleDownload(doc)} title="Download"
                  className="p-1.5 rounded-lg text-slate-400 hover:text-slate-900 hover:bg-slate-50 transition-colors">
                  <Download className="h-4 w-4" />
                </button>
                <button type="button" onClick={() => handleDelete(doc.claimDocId)} disabled={deletingId === doc.claimDocId} title="Delete"
                  className="p-1.5 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors disabled:opacity-40">
                  {deletingId === doc.claimDocId ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────
export default function SubmitNewClaim() {
  const navigate = useNavigate();
  const [form, setForm] = useState(EMPTY_FORM);
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(null);

  const set = (k) => (e) => {
    setForm((p) => ({ ...p, [k]: e.target.value }));
    if (errors[k]) setErrors((prev) => { const n = { ...prev }; delete n[k]; return n; });
  };

  const validate = () => {
    const e = {};
    if (!form.claimType) e.claimType = "Claim type is required.";
    if (!form.claimAmount || isNaN(form.claimAmount) || Number(form.claimAmount) < 1)
      e.claimAmount = "Amount must be at least ₹1.";
    if (!form.description) e.description = "Description is required.";
    else if (form.description.length < 10) e.description = "Must be at least 10 characters.";
    else if (form.description.length > 1000) e.description = "Must be 1000 characters or fewer.";
    if (!form.incidentDate) e.incidentDate = "Incident date & time is required.";
    if (!form.incidentAddress) e.incidentAddress = "Incident address is required.";
    else if (form.incidentAddress.length > 500) e.incidentAddress = "Max 500 characters.";
    if (!form.incidentCity) e.incidentCity = "City is required.";
    else if (form.incidentCity.length > 100) e.incidentCity = "Max 100 characters.";
    if (!form.incidentState) e.incidentState = "State is required.";
    else if (form.incidentState.length > 100) e.incidentState = "Max 100 characters.";
    return e;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const errs = validate();
    if (Object.keys(errs).length > 0) { setErrors(errs); return; }
    setErrors({});
    setLoading(true);
    try {
      const payload = { 
        ...form, 
        claimAmount: Number(form.claimAmount),
        incidentDate: new Date(form.incidentDate).toISOString()
      };
      const res = await addClaim(payload);
      setSubmitted(res.data?.data);
    } catch (err) {
      setErrors({ _global: err.response?.data?.message || "Failed to submit claim. Please try again." });
    } finally {
      setLoading(false);
    }
  };

  // ── Success screen — only document upload/download ─────────────────────
  if (submitted) {
    return (
      <DashboardLayout>
        <div className="max-w-3xl mx-auto space-y-6">
          {/* Success header */}
          <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
            <div className="flex items-center gap-4">
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-slate-100 shrink-0">
                <CheckCircle2 className="h-7 w-7 text-slate-900" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-slate-900">Claim Submitted Successfully!</h1>
                <p className="text-sm text-slate-500 mt-0.5">Your claim is now under review. Upload supporting documents below.</p>
              </div>
            </div>

            {/* Claim summary */}
            <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-3">
              {[
                { label: "Claim #", value: submitted.claimNumber, cls: "text-slate-900 font-semibold" },
                { label: "Type", value: submitted.claimType },
                { label: "Amount", value: `₹${Number(submitted.claimAmount).toLocaleString("en-IN")}` },
                { label: "Status", value: submitted.claimStatus?.replace(/_/g, " "), cls: "text-slate-900 font-medium" },
              ].map(({ label, value, cls = "text-slate-700 font-medium" }) => (
                <div key={label} className="bg-slate-50 rounded-lg px-3 py-2.5">
                  <p className="text-xs text-slate-400 mb-0.5">{label}</p>
                  <p className={`text-sm ${cls}`}>{value}</p>
                </div>
              ))}
            </div>
          </div>

          {/* Document upload */}
          <DocumentUploader claimId={submitted.claimId} />

          {/* Navigation */}
          <div className="flex gap-3">
            <button onClick={() => navigate("/customer/claims")}
              className="flex-1 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-sm font-medium px-5 py-2.5 transition-colors text-center">
              View My Claims
            </button>
            <button onClick={() => { setSubmitted(null); setForm(EMPTY_FORM); }}
              className="flex-1 rounded-lg border border-slate-200 hover:bg-slate-50 text-slate-600 text-sm font-medium px-5 py-2.5 transition-colors text-center">
              Submit Another
            </button>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  // ── Claim form — two-panel layout ────────────────────────────────────────
  return (
    <DashboardLayout>
      <div className="max-w-5xl mx-auto space-y-5">

        <div>
          <button onClick={() => navigate(-1)} className="flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-700 mb-3 transition-colors">
            <ArrowLeft className="h-4 w-4" /> Back
          </button>
          <h1 className="text-2xl font-bold text-slate-900">Submit New Claim</h1>
          <p className="text-sm text-slate-500 mt-0.5">Fill in all required fields to submit your insurance claim.</p>
        </div>

        {errors._global && (
          <div className="flex items-start gap-2.5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
            {errors._global}
          </div>
        )}

        <form onSubmit={handleSubmit} noValidate>
          {/* Two-column grid */}
          <div className="grid lg:grid-cols-2 gap-6">

            {/* LEFT — Claim Information */}
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6 space-y-5">
              <div className="flex items-center gap-2 pb-3 border-b border-slate-100">
                <FileText className="h-4 w-4 text-slate-900" />
                <h2 className="text-sm font-semibold text-slate-800">Claim Information</h2>
              </div>

              <Field label="Claim Type" required error={errors.claimType}>
                <select value={form.claimType} onChange={set("claimType")} className={inputCls(errors.claimType)}>
                  <option value="">Select a claim type…</option>
                  {CLAIM_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
                </select>
              </Field>

              <Field label="Claim Amount (₹)" required error={errors.claimAmount}>
                <div className="relative">
                  <IndianRupee className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 pointer-events-none" />
                  <input type="number" min="1" step="0.01" value={form.claimAmount} onChange={set("claimAmount")} placeholder="0.00" className={`${inputCls(errors.claimAmount)} pl-9`} />
                </div>
              </Field>

              <Field label="Description" required error={errors.description} hint={!errors.description ? `${form.description.length} / 1000 characters` : undefined}>
                <div className="relative">
                  <AlignLeft className="absolute left-3 top-3 h-4 w-4 text-slate-400 pointer-events-none" />
                  <textarea rows={5} value={form.description} onChange={set("description")} placeholder="Describe the incident in detail (min 10 characters)…" maxLength={1000} className={`${inputCls(errors.description)} pl-9 resize-none`} />
                </div>
              </Field>
            </div>

            {/* RIGHT — Incident Details */}
            <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6 space-y-5">
              <div className="flex items-center gap-2 pb-3 border-b border-slate-100">
                <MapPin className="h-4 w-4 text-slate-900" />
                <h2 className="text-sm font-semibold text-slate-800">Incident Details</h2>
              </div>

              <Field label="Incident Date & Time" required error={errors.incidentDate}>
                <div className="relative">
                  <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 pointer-events-none" />
                  <input type="datetime-local" value={form.incidentDate} max={new Date().toISOString().slice(0, 16)} onChange={set("incidentDate")} className={`${inputCls(errors.incidentDate)} pl-9`} />
                </div>
              </Field>

              <Field label="Incident Address" required error={errors.incidentAddress}>
                <input type="text" value={form.incidentAddress} onChange={set("incidentAddress")} placeholder="Street / area where the incident occurred" maxLength={500} className={inputCls(errors.incidentAddress)} />
              </Field>

              <div className="grid grid-cols-2 gap-4">
                <Field label="City" required error={errors.incidentCity}>
                  <input type="text" value={form.incidentCity} onChange={set("incidentCity")} placeholder="Mumbai" maxLength={100} className={inputCls(errors.incidentCity)} />
                </Field>
                <Field label="State" required error={errors.incidentState}>
                  <input type="text" value={form.incidentState} onChange={set("incidentState")} placeholder="Maharashtra" maxLength={100} className={inputCls(errors.incidentState)} />
                </Field>
              </div>
            </div>
          </div>

          {/* Submit button — full width below both panels */}
          <button type="submit" disabled={loading}
            className="w-full mt-6 flex items-center justify-center gap-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white font-medium py-3 text-sm transition-colors disabled:opacity-60 disabled:cursor-not-allowed shadow-sm">
            {loading ? <><Loader2 className="h-4 w-4 animate-spin" /> Submitting…</> : <><FileText className="h-4 w-4" /> Submit Claim</>}
          </button>
        </form>
      </div>
    </DashboardLayout>
  );
}
