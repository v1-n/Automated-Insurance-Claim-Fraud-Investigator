import 'document_model.dart';

class ClaimModel {
  final String id;
  final String? claimNumber;
  final String policyNumber;
  final double claimAmount;
  final String status;
  final double fraudScore;
  final String? fraudStatus;
  final String? riskLevel;
  final String? incidentDate;
  final String? createdAt;
  final String? updatedAt;
  final String? description;
  final String? claimType;
  final String? incidentAddress;
  final String? incidentCity;
  final String? incidentState;
  final String? policyHolderName;
  final String? customerName;
  final String? customerEmail;
  final String? assignedInvestigatorId;
  final String? assignedInvestigatorName;
  final String? reviewNotes;
  final String? decisionNotes;
  final List<DocumentModel> documents;

  // Policy Details
  final String? planName;
  final String? vehicleNumber;
  final String? vehicleMakeModel;
  final double? insuredDeclaredValue;
  final String? policyStartDate;
  final String? policyEndDate;
  final String? policyStatus;

  final bool reviewAllowed;

  ClaimModel({
    required this.id,
    this.claimNumber,
    required this.policyNumber,
    required this.claimAmount,
    required this.status,
    required this.fraudScore,
    this.fraudStatus,
    this.riskLevel,
    this.incidentDate,
    this.createdAt,
    this.updatedAt,
    this.description,
    this.claimType,
    this.incidentAddress,
    this.incidentCity,
    this.incidentState,
    this.policyHolderName,
    this.customerName,
    this.customerEmail,
    this.assignedInvestigatorId,
    this.assignedInvestigatorName,
    this.reviewNotes,
    this.decisionNotes,
    this.documents = const [],
    this.planName,
    this.vehicleNumber,
    this.vehicleMakeModel,
    this.insuredDeclaredValue,
    this.policyStartDate,
    this.policyEndDate,
    this.policyStatus,
    this.reviewAllowed = true,
  });

  /// Full incident location string
  String get incidentLocation {
    final parts = [incidentAddress, incidentCity, incidentState]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Location not provided' : parts.join(', ');
  }

  /// Whether this claim is pending investigation review
  bool get isPendingInvestigation {
    if (status == 'APPROVED' || status == 'REJECTED') return false;
    if (fraudStatus != null && fraudStatus != 'PENDING_ANALYSIS') return false;
    return true;
  }

  /// Whether this claim investigation is completed/reviewed
  bool get isCompletedInvestigation => !isPendingInvestigation;

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    return ClaimModel(
      id: (json['claimId'] ?? json['id'])?.toString() ?? '',
      claimNumber: json['claimNumber'] ?? json['claimId']?.toString(),
      policyNumber: json['policyNumber'] ?? json['policy']?['policyNumber'] ?? 'POL-N/A',
      claimAmount: (json['claimAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['claimStatus'] ?? json['status'] ?? 'PENDING',
      fraudScore: (json['fraudScore'] as num?)?.toDouble() ?? 0.0,
      fraudStatus: json['fraudStatus'],
      riskLevel: json['riskLevel'] ?? json['fraudRiskLevel'] ?? 'LOW',
      incidentDate: json['incidentDate']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      description: json['description'],
      claimType: json['claimType'] ?? json['category'],
      incidentAddress: json['incidentAddress'],
      incidentCity: json['incidentCity'],
      incidentState: json['incidentState'],
      policyHolderName: json['policyHolderName'] ?? json['customerName'] ?? json['user']?['fullName'],
      customerName: json['customerName'] ?? json['policyHolderName'] ?? json['user']?['fullName'],
      customerEmail: json['customerEmail'] ?? json['user']?['email'],
      assignedInvestigatorId: (json['investigatorId'] ?? json['assignedInvestigatorId'])?.toString(),
      assignedInvestigatorName: json['investigatorName'] ??
          json['assignedInvestigatorName'] ??
          json['investigator']?['fullName'] ??
          json['assignedInvestigator']?['fullName'],
      reviewNotes: json['reviewNotes'] ?? json['investigatorNotes'],
      decisionNotes: json['decisionNotes'] ?? json['adminNotes'],
      documents: json['documents'] != null
          ? (json['documents'] as List).map((d) => DocumentModel.fromJson(d)).toList()
          : [],
      planName: json['planName'] ?? json['policy']?['planName'],
      vehicleNumber: json['vehicleNumber'] ?? json['policy']?['vehicleNumber'],
      vehicleMakeModel: json['vehicleMakeModel'] ?? json['policy']?['vehicleMakeModel'],
      insuredDeclaredValue: (json['insuredDeclaredValue'] as num?)?.toDouble() ??
          (json['policy']?['insuredDeclaredValue'] as num?)?.toDouble(),
      policyStartDate: json['policyStartDate']?.toString() ?? json['policy']?['policyStartDate']?.toString(),
      policyEndDate: json['policyEndDate']?.toString() ?? json['policy']?['policyEndDate']?.toString(),
      policyStatus: json['policyStatus'] ?? json['policy']?['policyStatus'],
      reviewAllowed: json['reviewAllowed'] ?? true,
    );
  }

  String get tenantCode {
    if (claimNumber != null && claimNumber!.contains('-')) {
      return claimNumber!.split('-').first;
    }
    return 'TATA_AIG';
  }
}
