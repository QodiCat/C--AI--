import "dart:convert";

import "package:http/http.dart" as http;

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _httpClient.get(Uri.parse("$baseUrl$path"));
    return _decode(response.body);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.post(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    return _decode(response.body);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.patch(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(body ?? <String, dynamic>{}),
    );

    return _decode(response.body);
  }

  Map<String, dynamic> _decode(String responseBody) {
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}
