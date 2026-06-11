enum CloudProvider { firebase, yandex }

class CloudConfig {
  // ✅ Переключено на Яндекс.Облако
  static const CloudProvider provider = CloudProvider.yandex;

  static const yandexApiKey = '';
  static const yandexFunctionUrl = 'https://functions.yandexcloud.net/d4ebe398cf4irb742g3f';
  static const yandexStorageBucket = 'numino-files';
  static const yandexDbEndpoint = 'grpcs://ydb.serverless.yandexcloud.net:2135';
  static const yandexOAuthClientId = '0e4317419b05488097eed2e06c88400f';
}
