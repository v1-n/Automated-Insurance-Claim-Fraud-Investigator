import 'package:flutter/foundation.dart';
import '../models/claim_model.dart';
import '../models/document_model.dart';
import '../models/investigator_workload_model.dart';
import '../services/admin_service.dart';
import '../services/realtime_service.dart';

enum AdminClaimDetailStatus { idle, loading, loaded, error }

class AdminClaimDetailProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  final RealtimeService _realtimeService = RealtimeService();

  ClaimModel? claim;
  List<DocumentModel> documents = [];
  List<InvestigatorWorkloadModel> investigators = [];
  AdminClaimDetailStatus status = AdminClaimDetailStatus.idle;
  bool isProcessing = false;
  String? errorMessage;

  // Derived state
  bool get hasInvestigator =>
      claim != null &&
      claim!.assignedInvestigatorName != null &&
      claim!.assignedInvestigatorName!.trim().isNotEmpty &&
      claim!.assignedInvestigatorName != 'Not Assigned';

  bool get investigatorReviewDone =>
      claim != null &&
      claim!.reviewNotes != null &&
      claim!.reviewNotes!.trim().isNotEmpty;

  bool get hasDecision =>
      claim != null &&
      (claim!.status == 'APPROVED' || claim!.status == 'REJECTED');

  bool get canMakeDecision => !hasInvestigator || investigatorReviewDone;

  Future<void> load(String claimId) async {
    status = AdminClaimDetailStatus.loading;
    notifyListeners();
    try {
      final results = await Future.wait([
        _adminService.getAdminClaimById(claimId),
        _adminService.getAdminClaimDocuments(claimId),
        _adminService.getInvestigatorsWorkload(),
      ]);
      claim = results[0] as ClaimModel;
      documents = (results[1] as List<dynamic>)
          .map((d) => DocumentModel.fromJson(d as Map<String, dynamic>))
          .toList();
      investigators = results[2] as List<InvestigatorWorkloadModel>;
      status = AdminClaimDetailStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = AdminClaimDetailStatus.error;
    }
    notifyListeners();
  }

  Future<bool> assignInvestigator(String claimId, String investigatorId) async {
    isProcessing = true;
    notifyListeners();
    try {
      await _adminService.assignInvestigator(claimId, investigatorId);
      _realtimeService.emit(ClaimEventType.investigatorAssigned, claimId: claimId);
      await load(claimId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveClaim(String claimId, String notes) async {
    isProcessing = true;
    notifyListeners();
    try {
      await _adminService.approveClaim(claimId, notes);
      _realtimeService.emit(ClaimEventType.claimApproved, claimId: claimId);
      await load(claimId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectClaim(String claimId, String notes) async {
    isProcessing = true;
    notifyListeners();
    try {
      await _adminService.rejectClaim(claimId, notes);
      _realtimeService.emit(ClaimEventType.claimRejected, claimId: claimId);
      await load(claimId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      isProcessing = false;
      notifyListeners();
      return false;
    }
  }
}
