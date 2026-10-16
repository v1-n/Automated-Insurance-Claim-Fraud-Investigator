class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String? tenantCode;
  final String? status;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.tenantCode,
    this.status,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['userId'] ?? json['id'])?.toString() ?? '',
      fullName: json['fullName'] ?? json['name'] ?? 'User',
      email: json['email'] ?? '',
      role: json['role'] ?? 'USER',
      tenantCode: json['tenantCode'],
      status: json['status'],
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'tenantCode': tenantCode,
      'status': status,
      'avatarUrl': avatarUrl,
    };
  }
}
