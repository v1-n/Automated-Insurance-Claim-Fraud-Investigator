import axios from 'axios'
import { getAccessToken, clearAuthData } from '../utils/auth'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:8081/api/v1",
  headers: {
    "Content-Type": "application/json",
  },
});

api.interceptors.request.use(
  (config) => {
    const token = getAccessToken()
    if (token) config.headers.Authorization = `Bearer ${token}`
    return config
  },
  (error) => Promise.reject(error),
)

api.interceptors.response.use(
  (response) => response,

  async (error) => {

    const originalRequest = error.config;
    const isAuthRequest = originalRequest?.url?.includes("/auth/");

    if (
      error.response?.status === 401 &&
      !originalRequest._retry &&
      !isAuthRequest
    ) {

      originalRequest._retry = true;

      try {

        const refreshToken =
          localStorage.getItem("refreshToken");

        const apiBaseUrl = import.meta.env.VITE_API_URL || "http://localhost:8081/api/v1";
        const res = await axios.post(
          `${apiBaseUrl}/auth/refresh`,
          {
            refreshToken
          }
        );

        const newAccessToken =
          res.data.data.accessToken;

        localStorage.setItem(
          "accessToken",
          newAccessToken
        );

        originalRequest.headers.Authorization =
          `Bearer ${newAccessToken}`;

        return api(originalRequest);

      } catch {

        localStorage.clear();

        window.location.href = "/";

        return Promise.reject(error);
      }
    }

    return Promise.reject(error);
  }
);

export default api
