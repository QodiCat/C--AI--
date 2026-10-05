import '../../../core/network/api_client.dart';
import '../models/wardrobe_display_preferences.dart';

class WardrobeDisplayRepository {
  WardrobeDisplayRepository(this.client);
  final ApiClient client;
  Future<WardrobeDisplayPreferences> fetch() async {
    final response = await client.get('/me');
    return WardrobeDisplayPreferences.fromProfile(
        response['data'] as Map<String, dynamic>);
  }

  Future<void> save(WardrobeDisplayPreferences preferences) async {
    await client.patch('/me/wardrobe-display', body: preferences.toJson());
  }
}
