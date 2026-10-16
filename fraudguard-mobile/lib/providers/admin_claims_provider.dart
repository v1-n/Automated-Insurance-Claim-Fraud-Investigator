import 'package:flutter/foundation.dart';
import '../models/claim_model.dart';
import '../services/admin_service.dart';

class AdminClaimsProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  List<ClaimModel> _claims = [];
  bool _isLoading = false;
  String _selectedFilter = 'ALL';
  String? _errorMessage;

  List<ClaimModel> get claims => _claims;
  bool get isLoading => _isLoading;
  String get selectedFilter => _selectedFilter;
  String? get errorMessage => _errorMessage;

  List<ClaimModel> get filteredClaims {
    if (_selectedFilter == 'ALL') return _claims;
    if (_selectedFilter == 'UNASSIGNED') {
      return _claims.where((c) => c.assignedInvestigatorId == null || c.assignedInvestigatorId!.isEmpty).toList();
    }
    return _claims.where((c) => c.status == _selectedFilter).toList();
  }

  void setFilter(String filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      notifyListeners();
    }
  }

  Future<void> fetchClaims() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _adminService.getAllClaims();
      _claims = fetched;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
