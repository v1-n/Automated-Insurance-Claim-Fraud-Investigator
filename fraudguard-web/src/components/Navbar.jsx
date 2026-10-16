import { useState, useRef, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Bell, Search, ChevronDown, LogOut, UserCircle, Building2, ShieldAlert } from "lucide-react";
import { getUser, clearAuthData, getRefreshToken } from "../utils/auth";

import { logout } from "../services/authService";

// ── Logout Confirmation Modal ─────────────────────────────────────────────────
function LogoutModal({ onConfirm, onCancel }) { 
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
        onClick={onCancel}
      />
      {/* Dialog */}
      <div className="relative z-10 w-full max-w-sm mx-4 bg-white rounded-2xl shadow-2xl border border-slate-200 p-6">
        <div className="flex items-center justify-center w-12 h-12 rounded-full bg-red-50 mx-auto mb-4">
          <LogOut className="w-5 h-5 text-red-500" />
        </div>
        <h3 className="text-center text-base font-semibold text-slate-900 mb-1">
          Sign out?
        </h3>
        <p className="text-center text-sm text-slate-500 mb-6">
          You'll need to sign in again to access your account.
        </p>
        <div className="flex gap-3">
          <button
            onClick={onCancel}
            className="flex-1 py-2 px-4 rounded-lg border border-slate-200 text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="flex-1 py-2 px-4 rounded-lg bg-red-600 hover:bg-red-700 text-white text-sm font-medium transition-colors"
          >
            Sign out
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Navbar ────────────────────────────────────────────────────────────────────
export default function NavBar() {
  const navigate = useNavigate();
  const user = getUser();

  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [showLogoutModal, setShowLogoutModal] = useState(false);
  const dropdownRef = useRef(null);

  // Derive display values
  const initials =
    user?.fullName
      ?.split(" ")
      .map((n) => n[0])
      .join("")
      .toUpperCase()
      .slice(0, 2) || "??";

  const tenantName = user?.tenantCode
    ? user.tenantCode.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
    : "—";

  // Close dropdown on outside click
  useEffect(() => {
    function handleOutside(e) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setDropdownOpen(false);
      }
    }
    document.addEventListener("mousedown", handleOutside);
    return () => document.removeEventListener("mousedown", handleOutside);
  }, []);

  const handleLogoutConfirm = async () => {
    try {
      const payload = {
        refreshToken: getRefreshToken(),
      };
      await logout(payload);
    } catch (error) {
      console.error("Logout error:", error);
    } finally {
      setDropdownOpen(false);
      setShowLogoutModal(false);
      clearAuthData();
      navigate("/");
    }
  };

  return (
    <>
      <header className="sticky top-0 z-30 flex h-16 items-center gap-4 border-b border-slate-200 bg-white/85 backdrop-blur px-4 sm:px-6">

        {/* ── Brand / Left Area ── */}
        <div className="flex flex-1 items-center">
          <span className="text-sm font-semibold text-slate-800 lg:hidden">FraudGuard</span>
          <span className="hidden lg:inline-block text-sm font-semibold text-slate-800">FraudGuard</span>
        </div>

        {/* ── Right actions ── */}
        <div className="flex items-center gap-2">

          {/* Notification Bell */}
          <button className="relative flex items-center justify-center w-9 h-9 rounded-lg text-slate-500 hover:bg-slate-100 hover:text-slate-700 transition-colors">
            <Bell className="h-4.5 w-4.5" />
            {/* Unread badge */}
            <span className="absolute top-1.5 right-1.5 flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-red-500" />
            </span>
          </button>

          {/* Divider */}
          <div className="w-px h-6 bg-slate-200" />

          {/* Profile Dropdown */}
          <div className="relative" ref={dropdownRef}>
            <button
              id="profile-menu-btn"
              onClick={() => setDropdownOpen((prev) => !prev)}
              className="flex items-center gap-2.5 rounded-lg px-2 py-1.5 hover:bg-slate-100 transition-colors"
            >
              {/* Avatar */}
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-slate-900 text-xs font-semibold text-white shrink-0">
                {initials}
              </div>
              <div className="hidden sm:block text-left leading-tight">
                <p className="text-sm font-medium text-slate-800 leading-none">
                  {user?.fullName || "User"}
                </p>
                <p className="text-xs text-slate-400 mt-0.5">{tenantName}</p>
              </div>
              <ChevronDown
                className={`h-3.5 w-3.5 text-slate-400 transition-transform ${
                  dropdownOpen ? "rotate-180" : ""
                }`}
              />
            </button>

            {/* Dropdown Panel */}
            {dropdownOpen && (
              <div className="absolute right-0 top-full mt-2 w-64 rounded-xl border border-slate-200 bg-white shadow-xl shadow-slate-200/60 py-1.5 z-50">

                {/* User info header */}
                <div className="px-4 py-3 border-b border-slate-100">
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-900 text-sm font-bold text-white shrink-0">
                      {initials}
                    </div>
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-slate-900 truncate">
                        {user?.fullName || "—"}
                      </p>
                      <p className="text-xs text-slate-500 truncate">
                        {user?.email || "—"}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Tenant info */}
                <div className="px-4 py-2.5 border-b border-slate-100">
                  <div className="flex items-center gap-2 text-xs text-slate-500">
                    <Building2 className="h-3.5 w-3.5 shrink-0 text-slate-400" />
                    <span className="font-medium text-slate-600">{tenantName}</span>
                  </div>
                  <div className="flex items-center gap-2 text-xs text-slate-500 mt-1">
                    <ShieldAlert className="h-3.5 w-3.5 shrink-0 text-slate-400" />
                    <span>{user?.role || "—"}</span>
                  </div>
                </div>

                {/* Sign out */}
                <div className="px-1.5 pt-1.5">
                  <button
                    id="signout-btn"
                    onClick={() => {
                      setDropdownOpen(false);
                      setShowLogoutModal(true);
                    }}
                    className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-red-600 hover:bg-red-50 transition-colors"
                  >
                    <LogOut className="h-4 w-4" />
                    Sign out
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </header>

      {/* Logout Confirmation Modal */}
      {showLogoutModal && (
        <LogoutModal
          onConfirm={handleLogoutConfirm}
          onCancel={() => setShowLogoutModal(false)}
        />
      )}
    </>
  );
}
