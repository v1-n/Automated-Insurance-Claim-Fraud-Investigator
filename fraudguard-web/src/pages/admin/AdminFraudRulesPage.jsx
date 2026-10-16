import DashboardLayout from "../../components/DashboardLayout";
import { Settings2, Lock } from "lucide-react";

export default function AdminFraudRulesPage() {
  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Settings2 className="h-6 w-6 text-slate-900" /> Fraud Rules
          </h1>
          <p className="text-sm text-slate-500 mt-0.5">Configure fraud detection rules and thresholds.</p>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-12 flex flex-col items-center justify-center text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-slate-100 mb-4">
            <Lock className="h-8 w-8 text-slate-400" />
          </div>
          <h2 className="text-lg font-semibold text-slate-800 mb-1">Coming Soon</h2>
          <p className="text-sm text-slate-500 max-w-sm">
            Fraud rule engine configuration is under development. You'll be able to define 
            detection rules, set thresholds, and manage scoring models from here.
          </p>
          <div className="mt-6 inline-flex items-center rounded-full bg-slate-50 text-slate-900 text-xs font-medium px-3 py-1 ring-1 ring-slate-200">
            Planned for next release
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
