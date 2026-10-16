class AdminDashboardModel {
  final int totalClaims;
  final int pendingClaims;
  final int approvedClaims;
  final int rejectedClaims;
  final int suspectedFraudClaims;
  final int underReviewClaims;
  final int confirmedFraudClaims;
  final int activeClaims;
  final int clearClaims;

  AdminDashboardModel({
    required this.totalClaims,
    required this.pendingClaims,
    required this.approvedClaims,
    required this.rejectedClaims,
    required this.suspectedFraudClaims,
    required this.underReviewClaims,
    required this.confirmedFraudClaims,
    required this.activeClaims,
    required this.clearClaims,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      totalClaims: json['totalClaims'] ?? 0,
      pendingClaims: json['pendingClaims'] ?? 0,
      approvedClaims: json['approvedClaims'] ?? 0,
      rejectedClaims: json['rejectedClaims'] ?? 0,
      suspectedFraudClaims: json['suspectedFraudClaims'] ?? 0,
      underReviewClaims: json['underReviewClaims'] ?? 0,
      confirmedFraudClaims: json['confirmedFraudClaims'] ?? 0,
      activeClaims: json['activeClaims'] ?? 0,
      clearClaims: json['clearClaims'] ?? 0,
    );
  }
}
