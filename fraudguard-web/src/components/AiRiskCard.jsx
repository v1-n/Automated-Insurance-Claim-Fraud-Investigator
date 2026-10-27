import React, { useState } from "react";
import {
  ShieldAlert,
  AlertTriangle,
  CheckCircle2,
  Info,
  RefreshCw,
  ChevronDown,
  ChevronUp,
  Sparkles,
} from "lucide-react";

export default function AiRiskCard({ claim, onRerun, isRerunning = false }) {
  const [expandedFlags, setExpandedFlags] = useState({});

  if (!claim) return null;

  const aiStatus = (claim.aiStatus || claim.aiAnalysis?.status || (claim.fraudScore != null ? "DONE" : "PENDING")).toUpperCase();
  const score = claim.fraudScore ?? claim.aiAnalysis?.riskScore ?? 0;
  const riskLevel = claim.aiRiskLevel ?? claim.aiAnalysis?.riskLevel ?? (score >= 60 ? "HIGH" : score >= 25 ? "MEDIUM" : "LOW");
  const recommendation = claim.aiRecommendation ?? claim.aiAnalysis?.recommendation ?? (score >= 60 ? "INVESTIGATE" : score >= 25 ? "REVIEW" : "FAST_TRACK");
  const summary = claim.aiSummary ?? claim.aiAnalysis?.summary ?? (
    score >= 70
      ? "High probability of fraud matching standard patterns."
      : score >= 40
      ? "Moderate level of concerns. Manual inspection needed."
      : "Lower probability of fraud. Standard verification."
  );
  const flags = claim.aiAnalysis?.flags || [];

  const toggleFlag = (idx) => {
    setExpandedFlags((prev) => ({ ...prev, [idx]: !prev[idx] }));
  };

  const getRiskColor = (sc) => {
    if (sc >= 60) return "text-red-600 border-red-500 bg-red-50";
    if (sc >= 25) return "text-amber-600 border-amber-500 bg-amber-50";
    return "text-emerald-600 border-emerald-500 bg-emerald-50";
  };

  const getSeverityBadge = (sev) => {
    switch (sev?.toUpperCase()) {
      case "HIGH":
        return "bg-red-50 text-red-700 border-red-200";
      case "MEDIUM":
        return "bg-amber-50 text-amber-700 border-amber-200";
      case "LOW":
      default:
        return "bg-blue-50 text-blue-700 border-blue-200";
    }
  };

  const getRecommendationBadge = (rec) => {
    switch (rec?.toUpperCase()) {
      case "INVESTIGATE":
        return "bg-red-50 text-red-700 border-red-200";
      case "REVIEW":
        return "bg-amber-50 text-amber-700 border-amber-200";
      case "FAST_TRACK":
        return "bg-emerald-50 text-emerald-700 border-emerald-200";
      default:
        return "bg-slate-50 text-slate-700 border-slate-200";
    }
  };

  const formatCode = (code) => {
    if (!code) return "";
    return code
      .toLowerCase()
      .split("_")
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(" ");
  };

  // 1. PENDING / RUNNING
  if (aiStatus === "PENDING" || aiStatus === "RUNNING") {
    return (
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
        <div className="flex items-center gap-4">
          <div className="relative flex items-center justify-center">
            <RefreshCw className="h-8 w-8 text-blue-600 animate-spin" />
          </div>
          <div>
            <h3 className="text-base font-semibold text-slate-900 flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-blue-600" /> AI Fraud Analysis In Progress...
            </h3>
            <p className="text-sm text-slate-500 mt-1">
              Automated forensic analysis is inspecting submitted photos and claim metadata.
            </p>
          </div>
        </div>
      </div>
    );
  }

  // 2. FAILED
  if (aiStatus === "FAILED") {
    return (
      <div className="bg-red-50/50 rounded-xl border border-red-200 shadow-sm p-6">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-start gap-3">
            <AlertTriangle className="h-6 w-6 text-red-600 flex-shrink-0 mt-0.5" />
            <div>
              <h3 className="text-base font-semibold text-red-900">AI Analysis Unavailable</h3>
              <p className="text-sm text-red-700 mt-1">
                Automated analysis could not be completed. Please perform standard manual investigation.
              </p>
            </div>
          </div>
          {onRerun && (
            <button
              onClick={onRerun}
              disabled={isRerunning}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-red-600 text-white text-xs font-semibold rounded-lg hover:bg-red-700 disabled:opacity-50 transition-colors"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${isRerunning ? "animate-spin" : ""}`} />
              {isRerunning ? "Re-running..." : "Re-run Analysis"}
            </button>
          )}
        </div>
      </div>
    );
  }

  // 3. DONE (Score gauge + flags)
  const riskColorCls = getRiskColor(score);

  return (
    <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6 space-y-6">
      {/* Top Section: Score + Summary */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
        <div className="flex items-center gap-5">
          {/* Circular Risk Score */}
          <div className={`relative flex flex-col items-center justify-center w-20 h-20 rounded-full border-4 ${riskColorCls}`}>
            <span className="text-2xl font-black">{Math.round(score)}%</span>
            <span className="text-[10px] font-bold tracking-wider uppercase -mt-1">Risk</span>
          </div>

          <div>
            <div className="flex items-center gap-2 mb-1">
              <h2 className="text-base font-bold text-slate-900">AI Fraud Analysis</h2>
              <span className={`text-[11px] font-bold px-2 py-0.5 rounded-full border ${getSeverityBadge(riskLevel)}`}>
                {riskLevel} RISK
              </span>
              <span className={`text-[11px] font-bold px-2 py-0.5 rounded-full border ${getRecommendationBadge(recommendation)}`}>
                {recommendation.replace("_", " ")}
              </span>
            </div>
            <p className="text-sm text-slate-600 max-w-xl">{summary}</p>
          </div>
        </div>

        {onRerun && (
          <button
            onClick={onRerun}
            disabled={isRerunning}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 text-slate-700 text-xs font-semibold rounded-lg hover:bg-slate-50 disabled:opacity-50 transition-colors self-start sm:self-auto"
            title="Re-run AI Analysis"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${isRerunning ? "animate-spin" : ""}`} />
            {isRerunning ? "Running..." : "Re-run AI"}
          </button>
        )}
      </div>

      {/* Advisory Note */}
      <div className="flex items-center gap-2 px-3.5 py-2 bg-slate-50 border border-slate-100 rounded-lg text-xs text-slate-500 italic">
        <Info className="h-4 w-4 text-slate-400 flex-shrink-0" />
        <span>AI is advisory. The decision is yours.</span>
      </div>

      {/* Evidence Flags Section */}
      <div>
        <h3 className="text-sm font-bold text-slate-900 mb-3">
          {flags.length === 0 ? "Flagged Evidence: None" : `Why was this flagged? (${flags.length})`}
        </h3>

        {flags.length === 0 ? (
          <div className="flex items-center gap-2.5 p-3.5 rounded-lg border border-emerald-100 bg-emerald-50/50 text-xs text-emerald-800">
            <CheckCircle2 className="h-4 w-4 text-emerald-600 flex-shrink-0" />
            <span>No anomalous risk flags raised during photo forensics and sanity checks.</span>
          </div>
        ) : (
          <div className="space-y-3">
            {flags.map((flag, idx) => {
              const isExpanded = !!expandedFlags[idx];
              const hasDetails = (flag.benignExplanations && flag.benignExplanations.length > 0) ||
                                (flag.nextSteps && flag.nextSteps.length > 0);

              return (
                <div
                  key={idx}
                  className="rounded-lg border border-slate-200 bg-slate-50/50 overflow-hidden text-sm"
                >
                  <div
                    className={`p-3.5 flex items-start justify-between gap-3 ${hasDetails ? "cursor-pointer hover:bg-slate-100/50" : ""}`}
                    onClick={() => hasDetails && toggleFlag(idx)}
                  >
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded border uppercase ${getSeverityBadge(flag.severity)}`}>
                          {flag.severity}
                        </span>
                        <span className="font-semibold text-slate-900">{formatCode(flag.code)}</span>
                        {flag.confidence != null && (
                          <span className="text-xs text-slate-400">({Math.round(flag.confidence * 100)}% conf)</span>
                        )}
                      </div>
                      <p className="text-xs text-slate-600">{flag.explanation}</p>
                    </div>

                    {hasDetails && (
                      <button className="text-slate-400 hover:text-slate-600 p-1 flex-shrink-0">
                        {isExpanded ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
                      </button>
                    )}
                  </div>

                  {hasDetails && isExpanded && (
                    <div className="px-4 pb-3.5 pt-1 border-t border-slate-200/60 bg-white space-y-3 text-xs">
                      {flag.benignExplanations && flag.benignExplanations.length > 0 && (
                        <div>
                          <p className="font-semibold text-slate-700 mb-1">Possible innocent explanations:</p>
                          <ul className="list-disc list-inside space-y-0.5 text-slate-600">
                            {flag.benignExplanations.map((exp, eIdx) => (
                              <li key={eIdx}>{exp}</li>
                            ))}
                          </ul>
                        </div>
                      )}

                      {flag.nextSteps && flag.nextSteps.length > 0 && (
                        <div>
                          <p className="font-semibold text-slate-700 mb-1">Suggested next steps:</p>
                          <ul className="list-none space-y-0.5 text-slate-600">
                            {flag.nextSteps.map((step, sIdx) => (
                              <li key={sIdx} className="flex items-start gap-1.5">
                                <span className="text-blue-600 font-bold">→</span>
                                <span>{step}</span>
                              </li>
                            ))}
                          </ul>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
