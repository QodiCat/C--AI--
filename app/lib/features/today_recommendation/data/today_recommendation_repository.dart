import "../../../core/network/api_client.dart";

class TodayRecommendationRepository {
  TodayRecommendationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> generateTodayRecommendation(
      {required String weather,
      required String temperature,
      required String scene}) async {
    final response = await _apiClient.post(
      "/ai/today-recommendation/generate",
      body: {"weather": weather, "temperature": temperature, "scene": scene},
    );

    return response["data"] as List<dynamic>;
  }
}
