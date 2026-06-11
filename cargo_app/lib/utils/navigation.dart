export '_navigation_stub.dart'
    if (dart.library.html) '_navigation_web.dart'
    if (dart.library.io) '_navigation_mobile.dart';
