import "package:shared_preferences/shared_preferences.dart";

class AuthSession {
  static const _tokenKey = "access_token";
  static String? token;

  static Future<void> restore() async {
    token = (await SharedPreferences.getInstance()).getString(_tokenKey);
  }

  static Future<void> save(String value) async {
    token = value;
    await (await SharedPreferences.getInstance()).setString(_tokenKey, value);
  }

  static Future<void> clear() async {
    token = null;
    await (await SharedPreferences.getInstance()).remove(_tokenKey);
  }
}
