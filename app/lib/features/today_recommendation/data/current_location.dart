import 'dart:async';
import 'package:geolocator/geolocator.dart';

class Coordinates {
  const Coordinates(this.latitude, this.longitude);
  final double latitude, longitude;
}

Future<Coordinates> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('请开启设备定位服务后重试');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('定位权限已关闭，请在系统或浏览器设置中允许定位后重试');
    }
    if (permission == LocationPermission.denied) {
      throw Exception('需要允许定位，才能获取当前位置的天气');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
    );
    return Coordinates(position.latitude, position.longitude);
  } on TimeoutException {
    throw Exception('定位超时，请检查定位服务后重试');
  }
}
