import "../../../core/network/api_client.dart";

class WardrobeRepository {
  WardrobeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchItems() async {
    final response = await _apiClient.get("/items");
    return response["data"] as List<dynamic>;
  }
}
