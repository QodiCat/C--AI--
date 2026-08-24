import "../../../core/network/api_client.dart";

class TodayRecommendationRepository {
  TodayRecommendationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> generateTodayRecommendation() async {
    final response = await _apiClient.post(
      "/ai/today-recommendation/generate",
      body: {
        "weather": "晴",
        "temperature": "26",
        "scene": "上班"
      },
    );

    return response["data"] as List<dynamic>;
  }
}
