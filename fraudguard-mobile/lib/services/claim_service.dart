import '../core/network/api_client.dart';
import '../models/claim_model.dart';

class ClaimService {
  final ApiClient _api = ApiClient();

  Future<List<ClaimModel>> getMyClaims({
    int pageNumber = 0,
    int pageSize = 20,
    String sortBy = "CREATED_AT",
    String sortDir = "DESC",
  }) async {
    final response = await _api.get(
      '/claims/my',
      queryParams: {
        'pageNumber': pageNumber.toString(),
        'pageSize': pageSize.toString(),
        'sortBy': sortBy,
        'sortDir': sortDir,
      },
    );

    if (response != null) {
      final List content = response['content'] ?? (response is List ? response : []);
      return content.map((item) => ClaimModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<ClaimModel> getClaimById(String claimId) async {
    final response = await _api.get('/claims/$claimId');
    return ClaimModel.fromJson(response);
  }

  Future<ClaimModel> submitClaim({
    required double claimAmount,
    required String incidentDate,
    required String description,
    required String claimType,
    required String incidentAddress,
    required String incidentCity,
    required String incidentState,
  }) async {
    final response = await _api.post('/claims', body: {
      'claimAmount': claimAmount,
      'incidentDate': incidentDate,
      'description': description,
      'claimType': claimType,
      'incidentAddress': incidentAddress,
      'incidentCity': incidentCity,
      'incidentState': incidentState,
    });
    return ClaimModel.fromJson(response);
  }
}
