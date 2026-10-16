import 'package:flutter/foundation.dart';
import '../models/claim_model.dart';
import '../services/claim_service.dart';

class CustomerClaimsProvider extends ChangeNotifier {
  final ClaimService _claimService = ClaimService();

  List<ClaimModel> _claims = [];
  ClaimModel? _selectedClaim;
  bool _isLoading = false;
  String? _errorMessage;

  List<ClaimModel> get claims => _claims;
  ClaimModel? get selectedClaim => _selectedClaim;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMyClaims() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _claimService.getMyClaims();
      _claims = fetched;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchClaimById(String claimId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _claimService.getClaimById(claimId);
      _selectedClaim = fetched;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ClaimModel?> submitClaim({
    required double claimAmount,
    required String incidentDate,
    required String description,
    required String claimType,
    required String incidentAddress,
    required String incidentCity,
    required String incidentState,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _claimService.submitClaim(
        claimAmount: claimAmount,
        incidentDate: incidentDate,
        description: description,
        claimType: claimType,
        incidentAddress: incidentAddress,
        incidentCity: incidentCity,
        incidentState: incidentState,
      );
      await fetchMyClaims();
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
