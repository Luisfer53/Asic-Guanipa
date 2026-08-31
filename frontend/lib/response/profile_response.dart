
class ProfileResponse {
  final bool success;
  final ProfileData? data;

  ProfileResponse({required this.success, required this.data});

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      success: json['success'] ?? false,
      data: json["data"] != null ? ProfileData.fromJson(json['data']) : null,
    );
  }
}

class ProfileData {
  final int? id;
  final String? username;
  final String? email;

  ProfileData({required this.id, this.username, required this.email});

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'],
      email: json['email'],
      username: json['username'],
    );
  }
}
