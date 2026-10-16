import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;

  String get role => _currentUser?.role.toUpperCase() ?? '';
  bool get isAdmin => role == 'ADMIN';
  bool get isInvestigator => role == 'INVESTIGATOR';
  bool get isCustomer => role == 'USER' || role == 'CUSTOMER';

  AuthProvider() {
    ApiClient.onUnauthorized = () {
      logoutSilently();
    };
    initAuth();
  }

  Future<void> logoutSilently() async {
    dev.log('[AUTH] Silent logout triggered due to expired or invalid credentials.', name: 'AuthProvider');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> initAuth() async {
    dev.log('[AUTH] Initializing authentication session...', name: 'AuthProvider');
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('user');
      final token = prefs.getString(ApiClient.keyAccessToken);

      if (userJsonStr != null && token != null) {
        _currentUser = UserModel.fromJson(jsonDecode(userJsonStr));
        dev.log('[AUTH] Restored session for user: ${_currentUser?.email} (${_currentUser?.role})', name: 'AuthProvider');
      } else {
        dev.log('[AUTH] No saved session found.', name: 'AuthProvider');
      }
    } catch (e) {
      dev.log('[AUTH] Error initializing auth: $e', name: 'AuthProvider', error: e);
      _currentUser = null;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    dev.log('[AUTH] Attempting login for email: $email', name: 'AuthProvider');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _apiClient.post('/auth/login', body: {
        'email': email,
        'password': password,
      });

      if (data != null) {
        final prefs = await SharedPreferences.getInstance();
        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];
        final userData = data['user'];

        if (accessToken != null) {
          await prefs.setString(ApiClient.keyAccessToken, accessToken);
        }
        if (refreshToken != null) {
          await prefs.setString(ApiClient.keyRefreshToken, refreshToken);
        }
        if (userData != null) {
          await prefs.setString('user', jsonEncode(userData));
          _currentUser = UserModel.fromJson(userData);
        }

        dev.log('[AUTH] Login successful! User: ${_currentUser?.email}, Role: ${_currentUser?.role}', name: 'AuthProvider');
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      dev.log('[AUTH] Login failed for email $email. Error: $_errorMessage', name: 'AuthProvider', error: e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String tenantCode,
  }) async {
    dev.log('[AUTH] Registering new account - Email: $email, Name: $fullName, Tenant: $tenantCode', name: 'AuthProvider');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.post('/auth/register', body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'tenantCode': tenantCode,
      });

      dev.log('[AUTH] Registration successful for $email', name: 'AuthProvider');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      dev.log('[AUTH] Registration failed for $email. Error: $_errorMessage', name: 'AuthProvider', error: e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> forgotPassword(String email) async {
    dev.log('[AUTH] Requesting password reset for: $email', name: 'AuthProvider');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.post('/auth/forgot-password', body: {'email': email});
      dev.log('[AUTH] Password reset email triggered for: $email', name: 'AuthProvider');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      dev.log('[AUTH] Forgot password request failed for $email. Error: $_errorMessage', name: 'AuthProvider', error: e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> resendVerification(String email) async {
    dev.log('[AUTH] Requesting resend verification for: $email', name: 'AuthProvider');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.post('/auth/resend-verification', body: {'email': email});
      dev.log('[AUTH] Verification email re-sent to: $email', name: 'AuthProvider');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      dev.log('[AUTH] Resend verification failed for $email. Error: $_errorMessage', name: 'AuthProvider', error: e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    dev.log('[AUTH] Logging out user: ${_currentUser?.email}', name: 'AuthProvider');
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(ApiClient.keyRefreshToken);
      if (refreshToken != null) {
        await _apiClient.post('/auth/logout', body: {'refreshToken': refreshToken});
      }
    } catch (e) {
      dev.log('[AUTH] Error revoking refresh token during logout: $e', name: 'AuthProvider');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUser = null;
    dev.log('[AUTH] Logout complete. Session cleared.', name: 'AuthProvider');
    notifyListeners();
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    dev.log('[AUTH] Changing password for user', name: 'AuthProvider');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.post('/auth/change-password', body: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });
      dev.log('[AUTH] Password changed successfully', name: 'AuthProvider');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      dev.log('[AUTH] Change password failed. Error: $_errorMessage', name: 'AuthProvider', error: e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> deleteAccount(String password) async {
    dev.log('[AUTH] Deleting user account', name: 'AuthProvider');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.post('/auth/delete-account', body: {'password': password});
      dev.log('[AUTH] Account deleted successfully', name: 'AuthProvider');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      dev.log('[AUTH] Delete account failed. Error: $_errorMessage', name: 'AuthProvider', error: e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
