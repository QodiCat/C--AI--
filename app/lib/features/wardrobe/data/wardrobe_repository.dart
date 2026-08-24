import "../../../core/network/api_client.dart";

class WardrobeRepository {
  WardrobeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchItems(
      {String query = "", String category = ""}) async {
    final params = <String, String>{
      if (query.isNotEmpty) "q": query,
      if (category.isNotEmpty && category != "全部") "category": category
    };
    final path =
        Uri(path: "/items", queryParameters: params.isEmpty ? null : params)
            .toString();
    final response = await _apiClient.get(path);
    return response["data"] as List<dynamic>;
  }

  Future<void> createItem(Map<String, dynamic> item) async {
    await _apiClient.post("/items", body: item);
  }

  Future<void> updateStatus(
      String id, String management, String wearable) async {
    await _apiClient.patch("/items/$id/status",
        body: {"managementStatus": management, "wearableStatus": wearable});
  }

  Future<void> deleteItem(String id) async {
    await _apiClient.delete("/items/$id");
  }
}
