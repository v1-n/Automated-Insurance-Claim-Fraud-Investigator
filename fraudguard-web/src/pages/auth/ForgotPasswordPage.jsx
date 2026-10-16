import { useState } from "react";
import { Link } from "react-router-dom";
import { forgotPassword } from "../../services/authService";
import {
  Shield,
  Loader2,
  AlertCircle,
  CheckCircle2,
  ArrowLeft,
} from "lucide-react";

function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError("");
    setSuccess(false);
    setLoading(true);

    try {
      await forgotPassword(email);
      setSuccess(true);
    } catch (err) {
      setError(
        err.response?.data?.message ||
          "Failed to send reset link. Please try again.",
      );
    } finally {
      setLoading(false);
    }
  };

  if (success) {
    return (
      <div className="min-h-screen bg-slate-50/50 flex flex-col items-center justify-center px-4 py-10">
        <div className="w-full max-w-md bg-white rounded-2xl border border-slate-200/80 shadow-md p-8 text-center">
          <div className="inline-flex items-center justify-center w-14 h-14 bg-emerald-50 rounded-full mb-4 border border-emerald-100">
            <CheckCircle2 size={30} className="text-emerald-500" />
          </div>
          <h2 className="text-xl font-bold text-slate-900 mb-2">Reset Link Sent</h2>
          <p className="text-sm text-slate-500 mb-6 leading-relaxed">
            If an account exists for <span className="font-semibold text-slate-800">{email}</span>, a password reset link has been sent. Please check your inbox.
          </p>
          <Link
            to="/"
            className="inline-flex items-center justify-center w-full py-2.5 px-4 bg-slate-900 hover:bg-slate-800 text-white rounded-lg text-sm font-semibold transition-colors"
          >
            Go to Sign In
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-50/50 flex flex-col items-center justify-center px-4 py-10">
      <div className="w-full max-w-md">
        {/* Card */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-md p-8">
          
          {/* Logo Shield */}
          <div className="flex justify-center mb-4">
            <div className="inline-flex items-center justify-center w-12 h-12 bg-slate-950 rounded-full">
              <Shield size={20} className="text-white" />
            </div>
          </div>

          {/* Heading */}
          <div className="text-center mb-6">
            <h2 className="text-xl font-bold tracking-tight text-slate-900">Reset Password</h2>
            <p className="text-sm text-slate-500 mt-1">
              Enter your email to receive a password reset link
            </p>
          </div>

          {/* Error Alert */}
          {error && (
            <div className="mb-5 flex items-start gap-2.5 px-3.5 py-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
              <AlertCircle size={16} className="mt-0.5 shrink-0" />
              <span className="font-medium">{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email */}
            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                Email
              </label>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="user@example.com"
                className="w-full px-3.5 py-2.5 bg-slate-50/50 border border-slate-200 rounded-lg text-sm text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-slate-500/20 focus:border-slate-500 transition-colors"
              />
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading}
              className="w-full flex items-center justify-center gap-2 py-3 px-4 bg-slate-950 hover:bg-slate-900 text-white rounded-lg text-sm font-semibold disabled:opacity-55 disabled:cursor-not-allowed transition-colors mt-2"
            >
              {loading && <Loader2 size={16} className="animate-spin" />}
              {loading ? "Sending..." : "Send Reset Link"}
            </button>
          </form>

          {/* Footer Link */}
          <div className="flex justify-center mt-6">
            <Link
              to="/"
              className="inline-flex items-center gap-1.5 text-sm text-slate-600 hover:text-slate-950 font-semibold transition-colors"
            >
              <ArrowLeft size={14} />
              Back to login
            </Link>
          </div>

        </div>
      </div>
    </div>
  );
}

export default ForgotPasswordPage;
