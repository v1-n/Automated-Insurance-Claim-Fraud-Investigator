import 'package:flutter/foundation.dart';
import '../models/policy_plan_model.dart';
import '../models/user_policy_model.dart';
import '../services/policy_service.dart';

class PolicyProvider with ChangeNotifier {
  final PolicyService _policyService = PolicyService();

  List<PolicyPlanModel> _availablePlans = [];
  List<UserPolicyModel> _myPolicies = [];
  List<UserPolicyModel> _adminTenantPolicies = [];

  bool _isLoading = false;
  String? _error;

  List<PolicyPlanModel> get availablePlans => _availablePlans;
  List<UserPolicyModel> get myPolicies => _myPolicies;
  List<UserPolicyModel> get adminTenantPolicies => _adminTenantPolicies;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch plans available for customer selection
  Future<void> fetchAvailablePlans() async {
    _setLoading(true);
    try {
      _availablePlans = await _policyService.getAvailablePlans();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Fetch logged-in customer's active policies
  Future<void> fetchMyPolicies() async {
    _setLoading(true);
    try {
      _myPolicies = await _policyService.getMyPolicies();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Customer selects plan and activates policy
  Future<UserPolicyModel?> selectAndActivatePolicy({
    required int planId,
    required String vehicleNumber,
    required String vehicleMakeModel,
  }) async {
    _setLoading(true);
    try {
      final newPolicy = await _policyService.selectAndActivatePolicy(
        planId: planId,
        vehicleNumber: vehicleNumber,
        vehicleMakeModel: vehicleMakeModel,
      );
      _myPolicies.insert(0, newPolicy);
      _error = null;
      notifyListeners();
      return newPolicy;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Admin creates new policy plan
  Future<PolicyPlanModel?> createPolicyPlan({
    required String planName,
    required String policyType,
    required double maxIdvCoverage,
    required double annualPremium,
    required String description,
  }) async {
    _setLoading(true);
    try {
      final newPlan = await _policyService.createPolicyPlan(
        planName: planName,
        policyType: policyType,
        maxIdvCoverage: maxIdvCoverage,
        annualPremium: annualPremium,
        description: description,
      );
      _availablePlans.add(newPlan);
      _error = null;
      notifyListeners();
      return newPlan;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Admin fetches all tenant policies
  Future<void> fetchAdminTenantPolicies() async {
    _setLoading(true);
    try {
      _adminTenantPolicies = await _policyService.getAllTenantPolicies();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
