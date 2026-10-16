import 'package:flutter/foundation.dart';
import '../models/admin_dashboard_model.dart';
import '../models/claim_model.dart';
import '../services/admin_service.dart';

class AdminDashboardProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  AdminDashboardModel? _stats;
  List<ClaimModel> _unassignedClaims = [];
  bool _isLoading = false;
  String? _errorMessage;

  AdminDashboardModel? get stats => _stats;
  List<ClaimModel> get unassignedClaims => _unassignedClaims;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stats = await _adminService.getDashboardStats();
      final unassigned = await _adminService.getUnassignedClaims();
      _stats = stats;
      _unassignedClaims = unassigned;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
