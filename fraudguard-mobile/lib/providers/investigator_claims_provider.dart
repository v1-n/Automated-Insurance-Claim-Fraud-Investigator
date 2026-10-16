import 'package:flutter/foundation.dart';
import '../models/claim_model.dart';
import '../services/investigator_service.dart';

class InvestigatorClaimsProvider extends ChangeNotifier {
  final InvestigatorService _investigatorService = InvestigatorService();

  List<ClaimModel> _claims = [];
  ClaimModel? _selectedClaim;
  bool _isLoading = false;
  String? _errorMessage;

  List<ClaimModel> get claims => _claims;
  ClaimModel? get selectedClaim => _selectedClaim;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAssignedClaims() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _investigatorService.getAssignedClaims();
      _claims = fetched;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchClaimDetails(String claimId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _investigatorService.getClaimDetails(claimId);
      _selectedClaim = fetched;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ClaimModel?> submitReview({
    required String claimId,
    required String fraudStatus,
    required String reviewNotes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _investigatorService.reviewClaim(
        claimId: claimId,
        fraudStatus: fraudStatus,
        reviewNotes: reviewNotes,
      );
      await fetchAssignedClaims();
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
