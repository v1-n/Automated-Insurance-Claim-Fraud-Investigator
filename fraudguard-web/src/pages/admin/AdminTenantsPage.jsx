import DashboardLayout from "../../components/DashboardLayout";
import { Building2, Lock } from "lucide-react";

export default function AdminTenantsPage() {
  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Building2 className="h-6 w-6 text-slate-900" /> Tenants
          </h1>
          <p className="text-sm text-slate-500 mt-0.5">Manage tenant organizations and their configurations.</p>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-12 flex flex-col items-center justify-center text-center">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-slate-100 mb-4">
            <Lock className="h-8 w-8 text-slate-400" />
          </div>
          <h2 className="text-lg font-semibold text-slate-800 mb-1">Coming Soon</h2>
          <p className="text-sm text-slate-500 max-w-sm">
            Tenant management is under development. You'll be able to manage organizations, 
            configure tenant-specific settings, and control access from here.
          </p>
          <div className="mt-6 inline-flex items-center rounded-full bg-slate-50 text-slate-900 text-xs font-medium px-3 py-1 ring-1 ring-slate-200">
            Planned for next release
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
