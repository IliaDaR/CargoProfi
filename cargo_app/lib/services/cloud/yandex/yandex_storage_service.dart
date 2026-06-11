import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../cloud_interfaces.dart';
import '../cloud_config.dart';

class YandexStorageService implements ICloudStorage {
  String get _base => 'https://storage.yandexcloud.net/${CloudConfig.yandexStorageBucket}';

  @override
  Future<String?> uploadBytes(Uint8List bytes, String path, String contentType) async {
    final resp = await http.put(
      Uri.parse('$_base/$path'),
      headers: {'Content-Type': contentType, 'X-API-Key': CloudConfig.yandexApiKey},
      body: bytes,
    );
    return resp.statusCode == 200 ? '$_base/$path' : null;
  }

  @override
  Future<Uint8List?> downloadBytes(String path) async {
    final resp = await http.get(Uri.parse('$_base/$path'));
    return resp.statusCode == 200 ? resp.bodyBytes : null;
  }

  @override
  Future<void> deleteFile(String path) async {
    await http.delete(
      Uri.parse('$_base/$path'),
      headers: {'X-API-Key': CloudConfig.yandexApiKey},
    );
  }

  @override
  Future<String> getPublicUrl(String path) async => '$_base/$path';
}
