import "dart:convert";
import "dart:typed_data";

import "package:http/http.dart" as http;

import "auth_session.dart";

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        if (AuthSession.token != null)
          "Authorization": "Bearer ${AuthSession.token}",
      };

  Future<Map<String, dynamic>> get(String path) async {
    final response =
        await _httpClient.get(Uri.parse("$baseUrl$path"), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.post(
      Uri.parse("$baseUrl$path"),
      headers: _headers,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    return _decode(response);
  }

  Future<Map<String, dynamic>> upload(
      String path, Uint8List bytes, String fileName) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl$path"));
    if (AuthSession.token != null) {
      request.headers["Authorization"] = "Bearer ${AuthSession.token}";
    }
    request.files
        .add(http.MultipartFile.fromBytes("file", bytes, filename: fileName));
    final response = await http.Response.fromStream(
        await _httpClient.send(request).timeout(const Duration(seconds: 120)));
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.patch(
      Uri.parse("$baseUrl$path"),
      headers: _headers,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response =
        await _httpClient.delete(Uri.parse("$baseUrl$path"), headers: _headers);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException("服务器返回异常（HTTP ${response.statusCode}），请稍后重试");
    }
    if (response.statusCode >= 400 || decoded["success"] != true) {
      final error = decoded["error"] as Map<String, dynamic>?;
      throw ApiException(error?["message"]?.toString() ?? "请求失败");
    }
    return decoded;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
