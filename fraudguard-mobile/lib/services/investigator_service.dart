import 'dart:developer' as dev;
import '../core/network/api_client.dart';
import '../models/claim_model.dart';

class InvestigatorService {
  final ApiClient _api = ApiClient();

  Future<List<ClaimModel>> getAssignedClaims({
    int pageNumber = 0,
    int pageSize = 20,
    String sortBy = "CREATED_AT",
    String sortDir = "DESC",
  }) async {
    dev.log('[INVESTIGATOR_SERVICE] Fetching assigned investigation cases...', name: 'InvestigatorService');
    final response = await _api.get(
      '/investigator/claims',
      queryParams: {
        'pageNumber': pageNumber.toString(),
        'pageSize': pageSize.toString(),
        'sortBy': sortBy,
        'sortDir': sortDir,
      },
    );

    if (response != null) {
      final List content = response['content'] ?? (response is List ? response : []);
      dev.log('[INVESTIGATOR_SERVICE] Fetched ${content.length} assigned cases.', name: 'InvestigatorService');
      return content.map((item) => ClaimModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<ClaimModel> getClaimDetails(String claimId) async {
    dev.log('[INVESTIGATOR_SERVICE] Fetching investigation detail for claim: $claimId', name: 'InvestigatorService');
    final response = await _api.get('/investigator/claims/$claimId');
    return ClaimModel.fromJson(response);
  }

  Future<ClaimModel> reviewClaim({
    required String claimId,
    required String fraudStatus,
    required String reviewNotes,
  }) async {
    dev.log('[INVESTIGATOR_SERVICE] Submitting review for Claim: $claimId (Fraud Status: $fraudStatus)', name: 'InvestigatorService');
    final response = await _api.patch(
      '/investigator/claims/$claimId/review',
      body: {
        'fraudStatus': fraudStatus,
        'reviewNotes': reviewNotes,
      },
    );
    dev.log('[INVESTIGATOR_SERVICE] Investigation review submitted successfully for Claim: $claimId', name: 'InvestigatorService');
    return ClaimModel.fromJson(response);
  }
}
