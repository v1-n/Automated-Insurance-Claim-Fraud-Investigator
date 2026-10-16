class InvestigatorWorkloadModel {
  final String investigatorId;
  final String investigatorName;
  final String email;
  final int activeAssignedClaims;
  final int completedReviews;

  InvestigatorWorkloadModel({
    required this.investigatorId,
    required this.investigatorName,
    required this.email,
    required this.activeAssignedClaims,
    required this.completedReviews,
  });

  factory InvestigatorWorkloadModel.fromJson(Map<String, dynamic> json) {
    return InvestigatorWorkloadModel(
      investigatorId: json['investigatorId']?.toString() ?? json['id']?.toString() ?? '',
      investigatorName: json['investigatorName'] ?? json['fullName'] ?? 'Investigator',
      email: json['email'] ?? '',
      activeAssignedClaims: json['activeAssignedClaims'] ?? json['activeClaims'] ?? 0,
      completedReviews: json['completedReviews'] ?? json['totalCompleted'] ?? 0,
    );
  }
}
