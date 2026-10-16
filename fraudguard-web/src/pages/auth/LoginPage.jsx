import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { login, handleLoginSuccess, resendVerification } from "../../services/authService";

import {
  ShieldCheck,
  Eye,
  EyeOff,
  Loader2,
  Lock,
  AlertCircle,
  CheckCircle2,
} from "lucide-react";


function LoginPage() {
  const [form, setForm] = useState({ email: "", password: "" });
  const [showPwd, setShowPwd] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [resendStatus, setResendStatus] = useState("");
  const [resending, setResending] = useState(false);
  const navigate = useNavigate();

  const set = (k) => (e) => setForm((p) => ({ ...p, [k]: e.target.value }));

  const handleResend = async (email) => {
    setResending(true);
    setResendStatus("");
    try {
      await resendVerification(email);
      setResendStatus("Verification email sent! Please check your inbox.");
      setError("");
    } catch (err) {
      setResendStatus(
        err.response?.data?.message || "Failed to resend verification email."
      );
    } finally {
      setResending(false);
    }
  };

  const handleSubmit = async (event) => {
    event.preventDefault(); // Browser refresh is stopped
    setError("");
    setResendStatus("");
    setLoading(true);
    try {
      const res = await login(form);
      console.log(res.data);
      handleLoginSuccess(res.data.data, navigate);
    } catch (err) {
      const msg = err.response?.data?.message || "Login failed. Please check your credentials.";
      if (msg.toLowerCase().includes("email not verified") || msg.toLowerCase().includes("verified")) {
        setError("Your email address is not verified.");
      } else {
        setError(msg);
      }
    } finally {
      setLoading(false);
    }
  };
  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-center px-4 py-10">
      <div className="w-full max-w-sm">
        {/* Brand */}
        <div className="text-center mb-6">
          <div className="inline-flex items-center justify-center w-11 h-11 bg-black rounded-xl mb-3">
            <ShieldCheck size={22} className="text-white" />
          </div>
          <h1 className="text-xl font-semibold tracking-tight text-slate-900">
            FraudGuard
          </h1>
          <p className="text-sm text-slate-500 mt-0.5">
            Intelligent fraud detection platform
          </p>
        </div>

        {/* Card */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-8">
          {/* Error */}
          {error && (
            <div className="mb-5 flex flex-col gap-1.5 px-3.5 py-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
              <div className="flex items-start gap-2.5">
                <AlertCircle size={15} className="mt-0.5 shrink-0" />
                <span>{error}</span>
              </div>
              {error.toLowerCase().includes("verified") && (
                <button
                  type="button"
                  onClick={() => handleResend(form.email)}
                  disabled={resending}
                  className="text-xs text-red-800 font-semibold hover:underline mt-1 self-start disabled:opacity-50"
                >
                  {resending ? "Sending..." : "Didn't receive the email? Resend verification link"}
                </button>
              )}
            </div>
          )}

          {/* Resend Status Message */}
          {resendStatus && (
            <div className="mb-5 flex items-start gap-2.5 px-3.5 py-3 bg-emerald-50 border border-emerald-200 rounded-lg text-sm text-emerald-700">
              <CheckCircle2 size={15} className="mt-0.5 shrink-0" />
              <span>{resendStatus}</span>
            </div>
          )}

          {/* Heading */}
          <div className="mb-5">
            <h2 className="text-base font-medium text-slate-900">Sign in</h2>
            <p className="text-sm text-slate-500 mt-0.5">
              Access your FraudGuard workspace
            </p>
          </div>

          <hr className="border-slate-100 mb-5" />

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email */}
            <div>
              <label className="block text-xs font-medium text-slate-500 uppercase tracking-wide mb-1.5">
                Email address
              </label>
              <input
                type="email"
                required
                value={form.email}
                onChange={set("email")}
                placeholder="you@company.com"
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500 transition-colors"
              />
            </div>

            {/* Password */}
            <div>
              <label className="block text-xs font-medium text-slate-500 uppercase tracking-wide mb-1.5">
                Password
              </label>
              <div className="relative">
                <input
                  type={showPwd ? "text" : "password"}
                  required
                  value={form.password}
                  onChange={set("password")}
                  placeholder="••••••••"
                  className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-slate-500/30 focus:border-slate-500 transition-colors pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowPwd((p) => !p)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
                >
                  {showPwd ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
              <div className="flex justify-end mt-1.5">
                <Link
                  to="/forgot-password"
                  className="text-xs text-slate-900 hover:underline font-medium"
                >
                  Forgot password?
                </Link>
              </div>
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 py-2.5 px-4 bg-slate-900 hover:bg-slate-800 text-white rounded-lg text-sm font-medium disabled:opacity-55 disabled:cursor-not-allowed transition-colors mt-1"
            >
              {loading && <Loader2 size={15} className="animate-spin" />}
              {loading ? "Signing in…" : "Sign in"}
            </button>
          </form>

          <p className="text-center text-sm text-slate-500 mt-5">
            Don't have an account?{" "}
            <Link
              to="/register"
              className="text-slate-900 font-medium hover:underline"
            >
              Register
            </Link>
          </p>
        </div>

        {/* Trust badge */}
        <div className="flex justify-center mt-5">
          <span className="inline-flex items-center gap-1.5 text-xs text-slate-400 border border-slate-200 rounded-full px-3 py-1.5 bg-white">
            <Lock size={11} />
            256-bit encrypted &amp; SOC 2 compliant
          </span>
        </div>
      </div>
    </div>
  );
}

export default LoginPage;
