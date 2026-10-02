import "dart:typed_data";

import "package:http/http.dart" as http;

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
    final response = await _apiClient.post("/uploads/oss-signature", body: {
      "fileName": fileName,
      "contentType": contentType,
      "directory": "originals",
    });
    final data = response["data"] as Map<String, dynamic>;
    final request =
        http.MultipartRequest("POST", Uri.parse(data["uploadUrl"] as String));
    request.fields.addAll((data["formData"] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value.toString())));
    request.files
        .add(http.MultipartFile.fromBytes("file", bytes, filename: fileName));
    final uploaded = await request.send();
    if (uploaded.statusCode < 200 || uploaded.statusCode >= 300) {
      throw const ApiException("图片上传失败，请重试");
    }
    return data["objectUri"] as String;
  }

  Future<void> recognizeImage(String imageUri) async {
    await _apiClient.post("/ai/item-recognition/tasks", body: {
      "imageUrls": [imageUri]
    });
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
