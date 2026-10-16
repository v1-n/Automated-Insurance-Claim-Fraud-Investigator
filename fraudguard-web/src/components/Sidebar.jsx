import { NavLink, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard, FileText, Plus, Bell, UserCircle,
  ShieldAlert, Inbox, BarChart3, Users, Building2,
  Settings2, ScrollText, Workflow, Activity, ShieldCheck,
  ChevronRight, LogOut
} from "lucide-react";
import { getUser, clearAuthData } from '../utils/auth'

const customerNavs = [
  { to: "/customer/dashboard", label: "Dashboard", icon: LayoutDashboard, section: "Overview" },
  { to: "/customer/claims", label: "My Claims", icon: FileText, section: "Overview" },
  { to: "/customer/claims/new", label: "Submit Claim", icon: Plus, section: "Overview" },
  { to: "/customer/notifications", label: "Notifications", icon: Bell, section: "Account" },
  { to: "/customer/profile", label: "Profile", icon: UserCircle, section: "Account" },
]

const navsByRole = {
  customer: customerNavs,
  user: customerNavs, // backend sends role: 'USER'
  investigator: [
    { to: "/investigator/dashboard", label: "Dashboard", icon: LayoutDashboard, section: "Overview" },
    { to: "/investigator/claims", label: "Assigned Claims", icon: ShieldCheck, section: "Overview" },
    { to: "/investigator/notifications", label: "Notifications", icon: Bell, section: "Account" },
    { to: "/investigator/profile", label: "Profile", icon: UserCircle, section: "Account" },
  ],
  admin: [
    { to: "/admin/dashboard", label: "Overview", icon: LayoutDashboard, section: "Operations" },
    { to: "/admin/claims", label: "Claims", icon: FileText, section: "Operations" },

    { to: "/admin/workload", label: "Investigator Workload", icon: Activity, section: "Operations" },
    { to: "/admin/tenants", label: "Tenants", icon: Building2, section: "Management" },
    { to: "/admin/users", label: "Users & Roles", icon: Users, section: "Management" },
    { to: "/admin/rules", label: "Fraud Rules", icon: Settings2, section: "Configuration" },
    { to: "/admin/workflow", label: "Workflow", icon: Workflow, section: "Configuration" },
    { to: "/admin/logs", label: "System Logs", icon: ScrollText, section: "Configuration" },
    { to: "/admin/profile", label: "Profile", icon: UserCircle, section: "Account" },
  ],
}

function groupBySection(navs) {
  return navs.reduce((acc, item) => {
    if (!acc[item.section]) acc[item.section] = []
    acc[item.section].push(item)
    return acc
  }, {})
}

export default function Sidebar() {
  const navigate = useNavigate()
  const user = getUser()
  const roleKey = user?.role?.toLowerCase().replace('role_', '')
  const navs = navsByRole[roleKey] || []
  const grouped = groupBySection(navs)
  const initials = user?.fullName?.split(' ').map((n) => n[0]).join('').toUpperCase().slice(0, 2) || '??'

  const handleLogout = () => {
    clearAuthData()
    navigate('/login')
  }

  return (
    <aside className="hidden lg:flex sticky top-0 h-screen w-64 shrink-0 flex-col border-r border-slate-200 bg-white text-slate-900">

      {/* Brand */}
      <div className="flex h-16 items-center gap-3 px-5 border-b border-slate-100">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-50 border border-slate-200">
          <ShieldCheck className="h-5 w-5 text-slate-900" />
        </div>
        <div className="leading-tight">
          <p className="text-sm font-semibold text-slate-900">FraudGuard</p>
          <p className="text-[10px] uppercase tracking-wider text-slate-500">Insurance Platform</p>
        </div>
      </div>

      {/* Nav Links */}
      <nav className="flex-1 px-3 py-4 overflow-y-auto space-y-5">
        {Object.entries(grouped).map(([section, items]) => (
          <div key={section}>
            <p className="px-3 mb-1.5 text-[10px] font-semibold uppercase tracking-widest text-slate-500">
              {section}
            </p>

            <div className="space-y-0.5">
              {items.map(({ to, icon: Icon, label }) => (
                <NavLink
                  key={to}
                  to={to}
                  end
                  // ✅ className only — no children render prop conflict
                  className={({ isActive }) =>
                    `flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                      isActive
                        ? 'bg-slate-100 text-slate-900'
                        : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                    }`
                  }
                >
                  {/* ✅ Plain children — no render prop here */}
                  <Icon size={16} className="shrink-0" />
                  <span className="flex-1">{label}</span>
                </NavLink>
              ))}
            </div>
          </div>
        ))}
      </nav>

      {/* Sidebar Footer */}
      <div className="border-t border-slate-100 p-4 mt-auto">
        <div className="rounded-xl bg-slate-50 p-4 border border-slate-100/80">
          <p className="text-[11px] font-bold tracking-wider text-slate-800 uppercase">
            {roleKey === "admin" ? "ADMIN PORTAL" : roleKey === "investigator" ? "INVESTIGATOR PORTAL" : "CUSTOMER PORTAL"}
          </p>
          <p className="text-xs text-slate-400 mt-1 font-medium">
            FG-{new Date().getFullYear()}
          </p>
        </div>
      </div>

    </aside>
  )
}