class PolicyPlanModel {
  final int planId;
  final String planName;
  final String policyType;
  final double maxIdvCoverage;
  final double annualPremium;
  final String description;
  final bool isActive;
  final String? createdAt;

  PolicyPlanModel({
    required this.planId,
    required this.planName,
    required this.policyType,
    required this.maxIdvCoverage,
    required this.annualPremium,
    required this.description,
    required this.isActive,
    this.createdAt,
  });

  factory PolicyPlanModel.fromJson(Map<String, dynamic> json) {
    return PolicyPlanModel(
      planId: json['planId'] ?? 0,
      planName: json['planName'] ?? '',
      policyType: json['policyType'] ?? 'MOTOR_COMPREHENSIVE',
      maxIdvCoverage: (json['maxIdvCoverage'] ?? 0.0).toDouble(),
      annualPremium: (json['annualPremium'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      isActive: json['active'] ?? json['isActive'] ?? true,
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'planName': planName,
      'policyType': policyType,
      'maxIdvCoverage': maxIdvCoverage,
      'annualPremium': annualPremium,
      'description': description,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }
}
