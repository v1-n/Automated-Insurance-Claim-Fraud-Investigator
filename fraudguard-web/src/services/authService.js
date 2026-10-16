import api from "./api";
import { saveAuthData } from "../utils/auth";

export const login = (payload) => api.post("/auth/login", payload);
export const register = (payload) => api.post("/auth/register", payload);
export const verifyEmail = (token) => api.get("/auth/verify-email", {params: { token },});
export const forgotPassword = (email) =>api.post("/auth/forgot-password", {email,});
export const resetPassword = (payload) =>api.post("/auth/reset-password", payload);
export const logout = (payload) =>api.post("/auth/logout", payload);

export const resendVerification = (email) =>api.post("/auth/resend-verification", {email,});
export const deleteAccount = (payload) => api.post("/auth/delete-account", payload);

export const handleLoginSuccess = (data, navigate) => {
  saveAuthData(data.accessToken, data.refreshToken, data.user);
  const role = data.user?.role;
  console.log(role);
  if (role === "ADMIN")
    navigate("/admin/dashboard");
  else if (role === "INVESTIGATOR")
    navigate("/investigator/dashboard");
  else // USER / CUSTOMER
    navigate("/customer/dashboard");
};