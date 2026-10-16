import 'dart:developer' as dev;
import '../core/network/api_client.dart';
import '../models/admin_dashboard_model.dart';
import '../models/claim_model.dart';
import '../models/investigator_workload_model.dart';

class AdminService {
  final ApiClient _api = ApiClient();

  Future<AdminDashboardModel> getDashboardStats() async {
    dev.log('[ADMIN_SERVICE] Fetching admin dashboard metrics...', name: 'AdminService');
    final response = await _api.get('/admin/dashboard');
    dev.log('[ADMIN_SERVICE] Admin dashboard metrics retrieved successfully.', name: 'AdminService');
    return AdminDashboardModel.fromJson(response ?? {});
  }

  Future<List<ClaimModel>> getAllClaims({
    int pageNumber = 0,
    int pageSize = 20,
    String sortBy = "CREATED_AT",
    String sortDir = "DESC",
  }) async {
    dev.log('[ADMIN_SERVICE] Fetching all tenant claims...', name: 'AdminService');
    final response = await _api.get(
      '/admin/claims',
      queryParams: {
        'pageNumber': pageNumber.toString(),
        'pageSize': pageSize.toString(),
        'sortBy': sortBy,
        'sortDir': sortDir,
      },
    );

    if (response != null) {
      final List content = response['content'] ?? (response is List ? response : []);
      dev.log('[ADMIN_SERVICE] Fetched ${content.length} claims for admin review.', name: 'AdminService');
      return content.map((item) => ClaimModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<ClaimModel> getAdminClaimById(String claimId) async {
    dev.log('[ADMIN_SERVICE] Fetching admin claim detail for ID: $claimId', name: 'AdminService');
    final response = await _api.get('/admin/claims/$claimId');
    return ClaimModel.fromJson(response);
  }

  Future<List<dynamic>> getAdminClaimDocuments(String claimId) async {
    dev.log('[ADMIN_SERVICE] Fetching admin documents for claim ID: $claimId', name: 'AdminService');
    final response = await _api.get('/admin/claims/$claimId/documents');
    if (response is List) {
      dev.log('[ADMIN_SERVICE] Fetched ${response.length} documents for claim $claimId.', name: 'AdminService');
      return response;
    }
    return [];
  }

  Future<List<InvestigatorWorkloadModel>> getInvestigatorsWorkload() async {
    dev.log('[ADMIN_SERVICE] Fetching investigators workload distribution...', name: 'AdminService');
    final response = await _api.get('/admin/investigators/workload');
    if (response is List) {
      dev.log('[ADMIN_SERVICE] Fetched workload for ${response.length} investigators.', name: 'AdminService');
      return response.map((item) => InvestigatorWorkloadModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<void> assignInvestigator(String claimId, String investigatorId) async {
    dev.log('[ADMIN_SERVICE] Assigning Claim $claimId to Investigator $investigatorId', name: 'AdminService');
    await _api.patch(
      '/admin/claims/$claimId/assign-investigator',
      body: {'investigatorId': int.parse(investigatorId)},
    );
    dev.log('[ADMIN_SERVICE] Successfully assigned Claim $claimId to Investigator $investigatorId', name: 'AdminService');
  }

  Future<ClaimModel> approveClaim(String claimId, String decisionNotes) async {
    dev.log('[ADMIN_SERVICE] Approving Claim: $claimId with Notes: $decisionNotes', name: 'AdminService');
    final response = await _api.patch(
      '/admin/claims/$claimId/approve',
      body: {'decisionNotes': decisionNotes},
    );
    dev.log('[ADMIN_SERVICE] Claim $claimId APPROVED successfully.', name: 'AdminService');
    return ClaimModel.fromJson(response);
  }

  Future<ClaimModel> rejectClaim(String claimId, String decisionNotes) async {
    dev.log('[ADMIN_SERVICE] Rejecting Claim: $claimId with Notes: $decisionNotes', name: 'AdminService');
    final response = await _api.patch(
      '/admin/claims/$claimId/reject',
      body: {'decisionNotes': decisionNotes},
    );
    dev.log('[ADMIN_SERVICE] Claim $claimId REJECTED successfully.', name: 'AdminService');
    return ClaimModel.fromJson(response);
  }

  Future<List<ClaimModel>> getUnassignedClaims() async {
    dev.log('[ADMIN_SERVICE] Fetching unassigned claims...', name: 'AdminService');
    final response = await _api.get('/admin/claims/unassigned');
    if (response is List) {
      dev.log('[ADMIN_SERVICE] Fetched ${response.length} unassigned claims.', name: 'AdminService');
      return response.map((item) => ClaimModel.fromJson(item)).toList();
    }
    return [];
  }
}
