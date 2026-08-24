import "../../../core/network/api_client.dart";

class AiStylistRepository {
  AiStylistRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> generateOutfits() async {
    final response = await _apiClient.post(
      "/ai/outfits/generate",
      body: {
        "scene": "通勤",
        "season": "秋",
        "weather": "晴",
        "temperature": "24",
        "preferredStyle": "极简通勤"
      },
    );

    return response["data"] as List<dynamic>;
  }
}
