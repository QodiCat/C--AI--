import "../../../core/network/api_client.dart";

class AiStylistRepository {
  AiStylistRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> generateOutfits(
      {required String scene,
      required String season,
      required String weather,
      required String temperature,
      required String style}) async {
    final response = await _apiClient.post(
      "/ai/outfits/generate",
      body: {
        "scene": scene,
        "season": season,
        "weather": weather,
        "temperature": temperature,
        "preferredStyle": style
      },
    );

    return response["data"] as List<dynamic>;
  }

  Future<void> save(Map<String, dynamic> value) async {
    await _apiClient.post("/ai/outfits/save", body: value);
  }

  Future<void> feedback(String name, String feedback) async {
    await _apiClient.post("/ai/outfits/feedback",
        body: {"candidateName": name, "feedback": feedback});
  }
}
