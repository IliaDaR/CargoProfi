import '../../models/trip.dart';
import '../../models/expense.dart';
import '../../models/salary_rule.dart';
import 'cloud_interfaces.dart';
import 'cloud_config.dart';
import '../local_storage.dart';
import 'yandex/yandex_auth_service.dart';
import 'yandex/yandex_data_service.dart';
import 'yandex/yandex_storage_service.dart';
import 'yandex/yandex_functions_service.dart';

/// Factory that always returns Yandex Cloud implementations (Firebase removed)
class CloudFactory {
  static final _instances = <String, dynamic>{};

  static ICloudAuth get auth =>
      _instances['auth'] ??= YandexAuthService();

  static ICloudData get data =>
      _instances['data'] ??= YandexDataService();

  static ICloudStorage get storage =>
      _instances['storage'] ??= YandexStorageService();

  static ICloudFunctions get functions =>
      _instances['functions'] ??= YandexFunctionsService();

  static void reset() => _instances.clear();
}
