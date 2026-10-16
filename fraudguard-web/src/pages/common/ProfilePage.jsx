import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/DashboardLayout";
import { getUser, getRefreshToken, clearAuthData } from "../../utils/auth";
import { logout, deleteAccount, resetPassword } from "../../services/authService";
import { User, Mail, Shield, Building, CheckCircle, Calendar, Edit2, Lock, LogOut, Trash2, X, AlertCircle, Loader2 } from "lucide-react";
import { useState } from "react";

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

export default function ProfilePage() {
  const navigate = useNavigate();
  const user = getUser();
  const [loggingOut, setLoggingOut] = useState(false);
  const [modal, setModal] = useState(null); // null, 'edit', 'password'

  // Form states
  const [fullName, setFullName] = useState(user?.fullName || "");
  const [email, setEmail] = useState(user?.email || "");

  // Password states
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState("");
  const [passwordSuccess, setPasswordSuccess] = useState(false);

  // Delete account states
  const [deletePassword, setDeletePassword] = useState("");
  const [deleteLoading, setDeleteLoading] = useState(false);
  const [deleteError, setDeleteError] = useState("");

  // Derive display values
  const initials = user?.fullName?.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2) || "??";
  
  const handleSignOut = async () => {
    if (!window.confirm("Are you sure you want to sign out?")) return;
    try {
      setLoggingOut(true);
      await logout({ refreshToken: getRefreshToken() });
    } catch (err) {
      console.error(err);
    } finally {
      clearAuthData();
      navigate("/");
    }
  };

  const handleSaveProfile = (e) => {
    e.preventDefault();
    // Implementation would call API
    setModal(null);
  };

  const handleUpdatePassword = async (e) => {
    e.preventDefault();
    setPasswordError("");
    setPasswordSuccess(false);

    if (newPassword.length < 8) {
      setPasswordError("New password must be at least 8 characters long.");
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError("New passwords do not match.");
      return;
    }

    setPasswordLoading(true);

    try {
      const token = getAccessToken();
      await resetPassword({
        token,
        newPassword: newPassword,
      });
      setPasswordSuccess(true);
      setTimeout(() => {
        clearAuthData();
        setModal(null);
        navigate("/");
      }, 2000);
    } catch (err) {
      setPasswordError(
        err.response?.data?.message || "Failed to update password."
      );
    } finally {
      setPasswordLoading(false);
    }
  };

  const handleDeleteAccount = async (e) => {
    e.preventDefault();
    setDeleteError("");
    setDeleteLoading(true);
    try {
      await deleteAccount({ password: deletePassword });
      clearAuthData();
      setModal(null);
      setDeletePassword("");
      navigate("/");
    } catch (err) {
      setDeleteError(
        err.response?.data?.message || "Failed to delete account. Please check your password."
      );
    } finally {
      setDeleteLoading(false);
    }
  };

  const InfoRow = ({ icon: Icon, label, value }) => (
    <div className="flex items-center gap-3">
      <div className="flex items-center justify-center w-6 h-6 shrink-0">
        <Icon className="w-4 h-4 text-slate-400" />
      </div>
      <div className="flex flex-1 items-center">
        <span className="w-32 sm:w-48 text-sm text-slate-500">{label}</span>
        <span className="text-sm font-medium text-slate-900">{value}</span>
      </div>
    </div>
  );

  return (
    <DashboardLayout>
      <div className="max-w-3xl">
        <div className="mb-6 mt-4">
          <h1 className="text-2xl font-bold text-slate-900">My Profile</h1>
          <p className="text-sm text-slate-500 mt-1">Manage your account settings</p>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-6 mb-6">
          <div className="flex items-center gap-5 mb-8">
            <div className="flex items-center justify-center w-20 h-20 rounded-full bg-slate-100 text-2xl font-semibold text-slate-900 shrink-0">
              {initials}
            </div>
            <div>
              <h2 className="text-xl font-bold text-slate-900">{user?.fullName || "User"}</h2>
              <p className="text-sm text-slate-500 mt-0.5">{user?.email || "—"}</p>
              <div className="flex items-center gap-2 mt-3">
                <span className="inline-flex items-center px-2.5 py-0.5 rounded text-xs font-semibold uppercase tracking-wide bg-slate-100 text-slate-700">
                  {user?.role || "CUSTOMER"}
                </span>
                <span className="inline-flex items-center px-2.5 py-0.5 rounded text-xs font-semibold uppercase tracking-wide bg-emerald-50 text-emerald-700">
                  Active
                </span>
              </div>
            </div>
          </div>

          <div className="h-px bg-slate-100 w-full mb-6" />

          <div className="space-y-5">
            <InfoRow icon={User} label="Full Name" value={user?.fullName || "—"} />
            <InfoRow icon={Mail} label="Email" value={user?.email || "—"} />
            <InfoRow icon={Shield} label="Role" value={user?.role || "CUSTOMER"} />
            <InfoRow icon={Building} label="Tenant Code" value={user?.tenantCode || "—"} />
            <InfoRow icon={CheckCircle} label="Account Status" value="ACTIVE" />
            <InfoRow icon={Calendar} label="Member Since" value={user?.createdAt ? new Date(user.createdAt).toLocaleDateString() : "6/9/2026"} />
          </div>
        </div>

        <div className="grid sm:grid-cols-2 gap-4">
          <button onClick={() => setModal('edit')} className="flex items-center gap-3 px-4 py-3 bg-white border border-slate-200 rounded-xl hover:bg-slate-50 transition-colors text-sm font-semibold text-slate-700">
            <Edit2 className="w-4 h-4 text-slate-400" />
            Edit Profile
          </button>
          <button onClick={() => setModal('password')} className="flex items-center gap-3 px-4 py-3 bg-white border border-slate-200 rounded-xl hover:bg-slate-50 transition-colors text-sm font-semibold text-slate-700">
            <Lock className="w-4 h-4 text-slate-400" />
            Change Password
          </button>
          <button onClick={handleSignOut} disabled={loggingOut} className="flex items-center gap-3 px-4 py-3 bg-white border border-amber-200 rounded-xl hover:bg-amber-50 transition-colors text-sm font-semibold text-amber-600">
            <LogOut className="w-4 h-4" />
            {loggingOut ? "Signing out..." : "Sign Out"}
          </button>
          <button onClick={() => { setModal('delete'); setDeletePassword(""); setDeleteError(""); }} className="flex items-center gap-3 px-4 py-3 bg-white border border-red-200 rounded-xl hover:bg-red-50 transition-colors text-sm font-semibold text-red-600">
            <Trash2 className="w-4 h-4" />
            Delete Account
          </button>
        </div>

        {/* Modals */}
        {modal === 'edit' && (
          <ActionModal title="Edit Profile" onClose={() => setModal(null)}>
            <form onSubmit={handleSaveProfile} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-600 mb-1.5">Full Name</label>
                <input type="text" value={fullName} onChange={e => setFullName(e.target.value)}
                  className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-600 mb-1.5">Email</label>
                <input type="email" value={email} onChange={e => setEmail(e.target.value)}
                  className="w-full rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-500 cursor-not-allowed focus:outline-none" disabled />
              </div>
              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={() => setModal(null)} className="px-4 py-2 text-sm font-medium text-slate-600 hover:text-slate-800 transition-colors">Cancel</button>
                <button type="submit" className="px-4 py-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-sm font-medium transition-colors">Save Changes</button>
              </div>
            </form>
          </ActionModal>
        )}

        {modal === 'password' && (
          <ActionModal title="Change Password" onClose={() => setModal(null)}>
            <form onSubmit={handleUpdatePassword} className="space-y-4">
              {passwordError && (
                <div className="flex items-start gap-2.5 px-3 py-2.5 bg-red-50 border border-red-200 rounded-lg text-xs font-medium text-red-700">
                  <AlertCircle size={14} className="mt-0.5 shrink-0" />
                  <span>{passwordError}</span>
                </div>
              )}
              {passwordSuccess && (
                <div className="flex items-start gap-2.5 px-3 py-2.5 bg-emerald-50 border border-emerald-200 rounded-lg text-xs font-medium text-emerald-700">
                  <CheckCircle size={14} className="mt-0.5 shrink-0" />
                  <span>Password updated successfully. Logging out...</span>
                </div>
              )}
              <div>
                <label className="block text-xs font-semibold text-slate-600 mb-1.5">New Password</label>
                <input type="password" required value={newPassword} onChange={e => setNewPassword(e.target.value)}
                  className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-600 mb-1.5">Confirm New Password</label>
                <input type="password" required value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)}
                  className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500" />
              </div>
              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={() => setModal(null)} className="px-4 py-2 text-sm font-medium text-slate-600 hover:text-slate-800 transition-colors">Cancel</button>
                <button type="submit" disabled={passwordLoading} className="px-4 py-2 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-sm font-medium transition-colors disabled:opacity-50">
                  {passwordLoading ? "Updating..." : "Update Password"}
                </button>
              </div>
            </form>
          </ActionModal>
        )}

        {modal === 'delete' && (
          <ActionModal title="Delete Account" onClose={() => setModal(null)}>
            <form onSubmit={handleDeleteAccount} className="space-y-4">
              {deleteError && (
                <div className="flex items-start gap-2.5 px-3 py-2.5 bg-red-50 border border-red-200 rounded-lg text-xs font-medium text-red-700">
                  <AlertCircle size={14} className="mt-0.5 shrink-0" />
                  <span>{deleteError}</span>
                </div>
              )}
              <div className="p-3 bg-red-50/50 border border-red-100 rounded-lg">
                <p className="text-xs font-semibold text-red-800 uppercase tracking-wider mb-1">Warning</p>
                <p className="text-xs text-red-700 leading-relaxed">
                  This action is permanent and cannot be undone. All your claims and information will be archived/soft-deleted.
                </p>
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-600 mb-1.5">Enter Password to Confirm</label>
                <input
                  type="password"
                  required
                  value={deletePassword}
                  onChange={e => setDeletePassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500"
                />
              </div>
              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setModal(null)}
                  className="px-4 py-2 text-sm font-medium text-slate-600 hover:text-slate-800 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={deleteLoading}
                  className="px-4 py-2 rounded-lg bg-red-600 hover:bg-red-700 text-white text-sm font-medium transition-colors disabled:opacity-50 flex items-center gap-1.5"
                >
                  {deleteLoading && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                  Delete Account
                </button>
              </div>
            </form>
          </ActionModal>
        )}

      </div>
    </DashboardLayout>
  );
}
