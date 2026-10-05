import '../../../core/network/api_client.dart';
import 'current_location.dart';

class TodayRecommendationRepository {
  TodayRecommendationRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> generateTodayRecommendation(
      {required Coordinates location, required String scene}) async {
    final response =
        await _apiClient.post('/ai/today-recommendation/generate', body: {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'scene': scene,
    });
    return response['data'] as Map<String, dynamic>;
  }
}
