import "package:flutter/services.dart";

class AppConfig {
  static String apiBaseUrl = "http://localhost:3000";

  static Future<void> load() async {
    final contents = await rootBundle.loadString(".env");
    String? configuredUrl;
    for (final rawLine in contents.split("\n")) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith("#")) continue;
      final separator = line.indexOf("=");
      if (separator < 0) {
        throw const FormatException("app/.env 配置格式错误");
      }
      final key = line.substring(0, separator).trim();
      if (key != "API_BASE_URL") {
        throw const FormatException("app/.env 仅支持公开配置 API_BASE_URL");
      }
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      configuredUrl = value;
    }
    final url = configuredUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    final absolute = uri != null &&
        (uri.scheme == "http" || uri.scheme == "https") &&
        uri.host.isNotEmpty;
    final relative =
        url != null && url.startsWith("/") && !url.startsWith("//");
    if (url == null || url.isEmpty || (!absolute && !relative)) {
      throw const FormatException("请在 app/.env 设置有效的 API_BASE_URL");
    }
    apiBaseUrl = url;
  }
}
