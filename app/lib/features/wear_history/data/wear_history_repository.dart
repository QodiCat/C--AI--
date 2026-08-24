import "../../../core/network/api_client.dart";

class WearHistoryRepository {
  WearHistoryRepository(this.client);
  final ApiClient client;
  Future<List<dynamic>> outfits() async =>
      (await client.get("/outfits"))["data"] as List<dynamic>;
  Future<List<dynamic>> logs() async =>
      (await client.get("/wear-logs"))["data"] as List<dynamic>;
  Future<void> wear(String outfitId, {String note = ""}) async {
    final now = DateTime.now();
    final date =
        "${now.year.toString().padLeft(4, "0")}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}";
    await client.post("/wear-logs", body: {
      "outfitId": outfitId,
      "wearDate": date,
      "weather": "未记录",
      "temperature": "",
      "scene": "日常",
      "note": note
    });
  }

  Future<void> rate(String id, int rating) async {
    await client.patch("/outfits/$id/rating", body: {
      "rating": rating,
      "feedback": "like",
      "comfort": rating,
      "compliments": 0
    });
  }
}
