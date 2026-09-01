class StudentModel{
  final String id;
  final String name;
  final String rollNumber;
  final String classId;

  StudentModel({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.classId
});
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rollNumber': rollNumber,
      'classId': classId,
    };
  }
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      rollNumber: json['rollNumber'] ?? '',
      classId: json['classId'] ?? '',
    );
  }

}