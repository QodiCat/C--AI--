import "../../../core/network/api_client.dart";

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> login() {
    return _apiClient.post(
      "/auth/login",
      body: {"loginType": "phone", "credential": "demo-login-token"},
    );
  }
}
