import '../core/network/api_client.dart';
import '../models/policy_plan_model.dart';
import '../models/user_policy_model.dart';

class PolicyService {
  final ApiClient _api = ApiClient();

  // Customer: Get Available Policy Plans
  Future<List<PolicyPlanModel>> getAvailablePlans() async {
    final response = await _api.get('/policies/plans');
    if (response != null && response is List) {
      return response.map((item) => PolicyPlanModel.fromJson(item)).toList();
    }
    return [];
  }

  // Customer: Select & Activate Policy
  Future<UserPolicyModel> selectAndActivatePolicy({
    required int planId,
    required String vehicleNumber,
    required String vehicleMakeModel,
  }) async {
    final response = await _api.post('/policies/select', body: {
      'planId': planId,
      'vehicleNumber': vehicleNumber,
      'vehicleMakeModel': vehicleMakeModel,
    });
    return UserPolicyModel.fromJson(response);
  }

  // Customer: Get My Policies
  Future<List<UserPolicyModel>> getMyPolicies() async {
    final response = await _api.get('/policies/my-policies');
    if (response != null && response is List) {
      return response.map((item) => UserPolicyModel.fromJson(item)).toList();
    }
    return [];
  }

  // Admin: Create Policy Plan
  Future<PolicyPlanModel> createPolicyPlan({
    required String planName,
    required String policyType,
    required double maxIdvCoverage,
    required double annualPremium,
    required String description,
  }) async {
    final response = await _api.post('/admin/policies/plans', body: {
      'planName': planName,
      'policyType': policyType,
      'maxIdvCoverage': maxIdvCoverage,
      'annualPremium': annualPremium,
      'description': description,
    });
    return PolicyPlanModel.fromJson(response);
  }

  // Admin: Get All Tenant Policies
  Future<List<UserPolicyModel>> getAllTenantPolicies() async {
    final response = await _api.get('/admin/policies');
    if (response != null && response is List) {
      return response.map((item) => UserPolicyModel.fromJson(item)).toList();
    }
    return [];
  }
}
