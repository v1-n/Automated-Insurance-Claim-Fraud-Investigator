import 'document_model.dart';

class AiFlag {
  final String code;
  final String category;
  final String severity; // HIGH, MEDIUM, LOW
  final String explanation;
  final List<String> benignExplanations;
  final List<String> nextSteps;
  final double? confidence;

  AiFlag({
    required this.code,
    required this.category,
    required this.severity,
    required this.explanation,
    this.benignExplanations = const [],
    this.nextSteps = const [],
    this.confidence,
  });

  factory AiFlag.fromJson(Map<String, dynamic> json) {
    return AiFlag(
      code: json['code']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'LOW',
      explanation: json['explanation']?.toString() ?? '',
      benignExplanations: (json['benignExplanations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      nextSteps: (json['nextSteps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

class AiAnalysis {
  final String status;
  final double? riskScore;
  final String? riskLevel;
  final String? recommendation;
  final String? summary;
  final String? analyzedAt;
  final List<AiFlag> flags;

  AiAnalysis({
    required this.status,
    this.riskScore,
    this.riskLevel,
    this.recommendation,
    this.summary,
    this.analyzedAt,
    this.flags = const [],
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    return AiAnalysis(
      status: json['status']?.toString() ?? 'PENDING',
      riskScore: (json['riskScore'] as num?)?.toDouble(),
      riskLevel: json['riskLevel']?.toString(),
      recommendation: json['recommendation']?.toString(),
      summary: json['summary']?.toString(),
      analyzedAt: json['analyzedAt']?.toString(),
      flags: json['flags'] != null
          ? (json['flags'] as List<dynamic>)
              .map((f) => AiFlag.fromJson(f as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }
}

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

  // AI Analysis Details
  final String? aiStatus;
  final String? aiRiskLevel;
  final String? aiRecommendation;
  final String? aiSummary;
  final AiAnalysis? aiAnalysis;

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
    this.aiStatus,
    this.aiRiskLevel,
    this.aiRecommendation,
    this.aiSummary,
    this.aiAnalysis,
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
    final rawAiAnalysis = json['aiAnalysis'];
    final parsedAiAnalysis = rawAiAnalysis != null
        ? AiAnalysis.fromJson(rawAiAnalysis as Map<String, dynamic>)
        : null;

    final parsedAiStatus = json['aiStatus']?.toString() ??
        parsedAiAnalysis?.status ??
        (json['fraudScore'] != null ? 'DONE' : null);

    final parsedAiRiskLevel = json['aiRiskLevel']?.toString() ??
        parsedAiAnalysis?.riskLevel ??
        json['riskLevel']?.toString() ??
        json['fraudRiskLevel']?.toString();

    final parsedAiRecommendation = json['aiRecommendation']?.toString() ??
        parsedAiAnalysis?.recommendation;

    final parsedAiSummary = json['aiSummary']?.toString() ??
        parsedAiAnalysis?.summary;

    final parsedScore = (json['fraudScore'] as num?)?.toDouble() ??
        parsedAiAnalysis?.riskScore ??
        0.0;

    return ClaimModel(
      id: (json['claimId'] ?? json['id'])?.toString() ?? '',
      claimNumber: json['claimNumber'] ?? json['claimId']?.toString(),
      policyNumber: json['policyNumber'] ?? json['policy']?['policyNumber'] ?? 'POL-N/A',
      claimAmount: (json['claimAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['claimStatus'] ?? json['status'] ?? 'PENDING',
      fraudScore: parsedScore,
      fraudStatus: json['fraudStatus'],
      riskLevel: parsedAiRiskLevel ?? 'LOW',
      aiStatus: parsedAiStatus,
      aiRiskLevel: parsedAiRiskLevel,
      aiRecommendation: parsedAiRecommendation,
      aiSummary: parsedAiSummary,
      aiAnalysis: parsedAiAnalysis,
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
