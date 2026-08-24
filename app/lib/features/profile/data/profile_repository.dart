import "../../../core/network/api_client.dart";

class ProfileRepository {
  ProfileRepository(this.client);
  final ApiClient client;
  Future<Map<String, dynamic>> fetch() async =>
      (await client.get("/me"))["data"] as Map<String, dynamic>;
  Future<void> update(String nickname, String city, String bodyType) async {
    await client.patch("/me/profile",
        body: {"nickname": nickname, "city": city, "bodyType": bodyType});
  }

  Future<void> preferences(List<String> values) async {
    await client
        .patch("/me/style-preferences", body: {"stylePreferences": values});
  }

  Future<void> privacy(bool value) async {
    await client.patch("/me/privacy", body: {"allowModelTraining": value});
  }

  Future<void> deleteAccount() async {
    await client.delete("/me");
  }
}
