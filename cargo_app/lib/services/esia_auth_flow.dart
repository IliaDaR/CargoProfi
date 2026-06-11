// ESIA OAuth Flow (ЕСИА через Госуслуги)
// =========================================
// Интеграция с Единой системой идентификации и аутентификации (ЕСИА).
// Используется для авторизации в Госключе (УКЭП).
//
// Этапы:
// 1. Открыть https://esia.gosuslugi.ru/aas/oauth2/ac?client_id=... в WebView
// 2. Пользователь вводит логин/пароль Госуслуг
// 3. ЕСИА редиректит на redirect_uri с code
// 4. Обменять code на access_token через POST /aas/oauth2/te
// 5. Использовать токен для вызова API Госключа
//
// Настройки (будут заполнены после регистрации в ЕСИА):
class EsiaConfig {
  static const clientId = '';
  static const redirectUri = 'https://numino.ru/esia/callback';
  static const esiaBaseUrl = 'https://esia.gosuslugi.ru/aas/oauth2';
  static const scope = 'openid id_doc email mobile';
}

// Использование во Flutter:
// 1. Установить пакет webview_flutter или url_launcher
// 2. Открыть EsiaConfig.esiaBaseUrl + '/ac' с параметрами
// 3. Перехватить редирект с code через NavigationDelegate
// 4. Вызвать Cloud Function /esia/callback для обмена code на токен
