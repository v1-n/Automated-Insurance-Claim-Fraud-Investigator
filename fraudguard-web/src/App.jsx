import { Routes, Route, Navigate } from 'react-router-dom'
import { getUser, getAccessToken } from "./utils/auth";

import LoginPage from './pages/auth/LoginPage'
import RegisterPage from "./pages/auth/RegisterPage";
import ForgotPasswordPage from "./pages/auth/ForgotPasswordPage";
import ResetPasswordPage from "./pages/auth/ResetPasswordPage";
import CustomerDashboard from "./pages/customer/CustomerDashboard";
import MyClaimPage from './pages/customer/MyClaimPage';
import ClaimDetailPage from './pages/customer/ClaimDetailPage';
import SubmitNewClaim from './pages/customer/SubmitNewClaim';
import ProfilePage from './pages/common/ProfilePage';
import NotificationPage from './pages/common/NotificationPage';
import AdminDashboard from "./pages/admin/AdminDashboard";
import AdminClaimsPage from "./pages/admin/AdminClaimsPage";
import AdminClaimDetailPage from "./pages/admin/AdminClaimDetailPage";
import AdminWorkloadPage from "./pages/admin/AdminWorkloadPage";
import AdminTenantsPage from "./pages/admin/AdminTenantsPage";
import AdminUsersPage from "./pages/admin/AdminUsersPage";
import AdminFraudRulesPage from "./pages/admin/AdminFraudRulesPage";
import AdminWorkflowPage from "./pages/admin/AdminWorkflowPage";
import AdminLogsPage from "./pages/admin/AdminLogsPage";
import InvestigatorDashboard from "./pages/investigator/InvestigatorDashboard";
import InvestigatorClaimsPage from "./pages/investigator/InvestigatorClaimsPage";
import InvestigatorClaimDetailPage from "./pages/investigator/InvestigatorClaimDetailPage";

function ProtectedRoute({ children, allowedRoles }) {
  const token = getAccessToken();
  const user = getUser();

  if (!token || !user) {
    return <Navigate to="/" replace />;
  }

  if (allowedRoles && !allowedRoles.includes(user.role)) {
    if (user.role === "ADMIN") {
      return <Navigate to="/admin/dashboard" replace />;
    } else if (user.role === "INVESTIGATOR") {
      return <Navigate to="/investigator/dashboard" replace />;
    } else {
      return <Navigate to="/customer/dashboard" replace />;
    }
  }

  return children;
}

function GuestRoute({ children }) {
  const token = getAccessToken();
  const user = getUser();

  if (token && user) {
    if (user.role === "ADMIN") {
      return <Navigate to="/admin/dashboard" replace />;
    } else if (user.role === "INVESTIGATOR") {
      return <Navigate to="/investigator/dashboard" replace />;
    } else {
      return <Navigate to="/customer/dashboard" replace />;
    }
  }

  return children;
}

function App() {
  return (
    <Routes>
      <Route path="/" element={<GuestRoute><LoginPage /></GuestRoute>} />
      <Route path="/register" element={<GuestRoute><RegisterPage /></GuestRoute>} />
      <Route path="/forgot-password" element={<GuestRoute><ForgotPasswordPage /></GuestRoute>} />
      <Route path="/reset-password" element={<GuestRoute><ResetPasswordPage /></GuestRoute>} />

      {/* Customer */}
      <Route path="/customer/dashboard" element={<ProtectedRoute allowedRoles={["USER", "CUSTOMER"]}><CustomerDashboard /></ProtectedRoute>} />
      <Route path="/customer/claims" element={<ProtectedRoute allowedRoles={["USER", "CUSTOMER"]}><MyClaimPage /></ProtectedRoute>} />
      <Route path="/customer/claims/new" element={<ProtectedRoute allowedRoles={["USER", "CUSTOMER"]}><SubmitNewClaim /></ProtectedRoute>} />
      <Route path="/customer/claims/:claimId" element={<ProtectedRoute allowedRoles={["USER", "CUSTOMER"]}><ClaimDetailPage /></ProtectedRoute>} />
      <Route path="/customer/notifications" element={<ProtectedRoute allowedRoles={["USER", "CUSTOMER"]}><NotificationPage /></ProtectedRoute>} />
      <Route path="/customer/profile" element={<ProtectedRoute allowedRoles={["USER", "CUSTOMER"]}><ProfilePage /></ProtectedRoute>} />

      {/* Admin */}
      <Route path="/admin/dashboard" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminDashboard /></ProtectedRoute>} />
      <Route path="/admin/claims" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminClaimsPage /></ProtectedRoute>} />
      <Route path="/admin/claims/:claimId" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminClaimDetailPage /></ProtectedRoute>} />
      <Route path="/admin/workload" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminWorkloadPage /></ProtectedRoute>} />
      <Route path="/admin/tenants" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminTenantsPage /></ProtectedRoute>} />
      <Route path="/admin/users" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminUsersPage /></ProtectedRoute>} />
      <Route path="/admin/rules" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminFraudRulesPage /></ProtectedRoute>} />
      <Route path="/admin/workflow" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminWorkflowPage /></ProtectedRoute>} />
      <Route path="/admin/logs" element={<ProtectedRoute allowedRoles={["ADMIN"]}><AdminLogsPage /></ProtectedRoute>} />
      <Route path="/admin/profile" element={<ProtectedRoute allowedRoles={["ADMIN"]}><ProfilePage /></ProtectedRoute>} />

      {/* Investigator */}
      <Route path="/investigator/dashboard" element={<ProtectedRoute allowedRoles={["INVESTIGATOR"]}><InvestigatorDashboard /></ProtectedRoute>} />
      <Route path="/investigator/claims" element={<ProtectedRoute allowedRoles={["INVESTIGATOR"]}><InvestigatorClaimsPage /></ProtectedRoute>} />
      <Route path="/investigator/claims/:claimId" element={<ProtectedRoute allowedRoles={["INVESTIGATOR"]}><InvestigatorClaimDetailPage /></ProtectedRoute>} />
      <Route path="/investigator/notifications" element={<ProtectedRoute allowedRoles={["INVESTIGATOR"]}><NotificationPage /></ProtectedRoute>} />
      <Route path="/investigator/profile" element={<ProtectedRoute allowedRoles={["INVESTIGATOR"]}><ProfilePage /></ProtectedRoute>} />
    </Routes>
  );
}

export default App;