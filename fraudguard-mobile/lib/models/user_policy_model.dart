class UserPolicyModel {
  final int policyId;
  final String policyNumber;
  final String planName;
  final String policyType;
  final String vehicleNumber;
  final String vehicleMakeModel;
  final double insuredDeclaredValue;
  final String policyStatus;
  final String policyStartDate;
  final String policyEndDate;
  final String userName;
  final String userEmail;
  final String tenantCode;

  UserPolicyModel({
    required this.policyId,
    required this.policyNumber,
    required this.planName,
    required this.policyType,
    required this.vehicleNumber,
    required this.vehicleMakeModel,
    required this.insuredDeclaredValue,
    required this.policyStatus,
    required this.policyStartDate,
    required this.policyEndDate,
    required this.userName,
    required this.userEmail,
    required this.tenantCode,
  });

  factory UserPolicyModel.fromJson(Map<String, dynamic> json) {
    return UserPolicyModel(
      policyId: json['policyId'] ?? 0,
      policyNumber: json['policyNumber'] ?? '',
      planName: json['planName'] ?? 'Motor Comprehensive Plan',
      policyType: json['policyType'] ?? 'MOTOR_COMPREHENSIVE',
      vehicleNumber: json['vehicleNumber'] ?? '',
      vehicleMakeModel: json['vehicleMakeModel'] ?? '',
      insuredDeclaredValue: (json['insuredDeclaredValue'] ?? 0.0).toDouble(),
      policyStatus: json['policyStatus'] ?? 'ACTIVE',
      policyStartDate: json['policyStartDate'] ?? '',
      policyEndDate: json['policyEndDate'] ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      tenantCode: json['tenantCode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'policyId': policyId,
      'policyNumber': policyNumber,
      'planName': planName,
      'policyType': policyType,
      'vehicleNumber': vehicleNumber,
      'vehicleMakeModel': vehicleMakeModel,
      'insuredDeclaredValue': insuredDeclaredValue,
      'policyStatus': policyStatus,
      'policyStartDate': policyStartDate,
      'policyEndDate': policyEndDate,
      'userName': userName,
      'userEmail': userEmail,
      'tenantCode': tenantCode,
    };
  }
}
