import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cloud/yandex/yandex_functions_service.dart';
import 'cloud/yandex/yandex_data_service.dart';
import 'cloud/yandex/yandex_auth_service.dart';
import 'cloud/yandex/yandex_storage_service.dart';
import 'cloud/cloud_interfaces.dart';

/// Yandex-only bridge — без Firebase-импортов
/// Все операции идут через Cloud Functions (?endpoint=...)
class YandexBridge {
  static final YandexBridge instance = YandexBridge._();
  YandexBridge._();

  late final ICloudFunctions functions = YandexFunctionsService();
  late final ICloudData data = YandexDataService();
  late final ICloudAuth auth = YandexAuthService();
  late final ICloudStorage storage = YandexStorageService();

  Future<bool> healthCheck() async {
    try {
      final resp = await http.get(
        Uri.parse('https://functions.yandexcloud.net/d4ebe398cf4irb742g3f?endpoint=ping'),
      ).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
