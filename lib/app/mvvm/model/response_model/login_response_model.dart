/// Parsed `data` payload returned by the login endpoint.
class LoginResponseModel {
  const LoginResponseModel({this.token, this.name});

  final String? token;
  final String? name;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      LoginResponseModel(
        token: json['token'] as String?,
        name: json['name'] as String?,
      );

  Map<String, dynamic> toJson() => {'token': token, 'name': name};
}
