import 'dart:convert';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? classId;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.classId,
});

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'classId': classId,
    };
  }
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'teacher',
      classId: json['classId'],
    );
  }

}