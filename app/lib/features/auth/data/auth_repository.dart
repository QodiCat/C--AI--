import "../../../core/network/api_client.dart";

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> login(String email, String password) {
    return _apiClient.post(
      "/auth/login",
      body: {"email": email, "password": password},
    );
  }

  Future<Map<String, dynamic>> register(
      String email, String password, String nickname) {
    return _apiClient.post("/auth/register",
        body: {"email": email, "password": password, "nickname": nickname});
  }

  Future<Map<String, dynamic>> logout() => _apiClient.post("/auth/logout");
}
