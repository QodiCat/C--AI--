import "dart:typed_data";

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

  Future<String> uploadImage(
      Uint8List bytes, String fileName, String contentType) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw const ApiException("图片不能超过10 MB");
    }
    final response =
        await _apiClient.upload("/uploads/images", bytes, fileName);
    return response["data"]["objectUri"] as String;
  }

  Future<String?> resolveImage(String uri) async {
    if (uri.isEmpty) return null;
    if (!uri.startsWith("oss://")) return uri;
    final response = await _apiClient.get(
        Uri(path: "/uploads/oss-url", queryParameters: {"objectUri": uri})
            .toString());
    return response["data"]["url"] as String;
  }

  Future<Map<String, dynamic>> recognizeImage(String imageUri) async {
    final created = await _apiClient.post("/ai/item-recognition/tasks", body: {
      "imageUrls": [imageUri]
    });
    final id = created["data"]["id"] as String;
    final deadline = DateTime.now().add(const Duration(minutes: 11));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final response = await _apiClient.get("/ai/tasks/$id");
      final task = response["data"] as Map<String, dynamic>;
      if (task["status"] == "failed") {
        throw ApiException(task["errorMessage"] as String? ?? "图片处理失败");
      }
      if (task["status"] == "success") {
        final candidates = task["result"] as List<dynamic>;
        if (candidates.isEmpty) throw const ApiException("未识别到衣物或鞋子");
        return Map<String, dynamic>.from(candidates.first as Map);
      }
    }
    throw const ApiException("识别超时，请稍后重试");
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
