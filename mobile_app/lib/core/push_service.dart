import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// Foreground banner channel (must match the channel created in [init]).
const String pushChannelId = 'orvix_push';

/// FCM topic every customer device subscribes to for new-product broadcasts.
const String newProductsTopic = 'new_products';

/// Pure tap mapper: FCM `data` payload → in-app route.
///
/// - `{type: new_product, productId}` → `/product/:id`
/// - `{type: order_update, orderId}` → `/orders/:id`
/// - anything else (unknown type, missing/empty id) → null (stay put).
///
/// Kept pure (no Firebase) so `mobile_app/test/push_test.dart` can
/// unit-test it without plugins.
String? routeForPush(Map<String, String> data) {
  final type = data['type'];
  if (type == 'new_product') {
    final id = data['productId'];
    if (id == null || id.isEmpty) return null;
    return '/product/$id';
  }
  if (type == 'order_update') {
    final id = data['orderId'];
    if (id == null || id.isEmpty) return null;
    return '/orders/$id';
  }
  return null;
}

/// Background/terminated tap handler. MUST stay a top-level function for
/// `FirebaseMessaging.onBackgroundMessage`. Only re-inits Firebase so the
/// isolate is usable; tap routing for background opens is delivered via
/// `onMessageOpenedApp` / `getInitialMessage` in [PushService.init].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Broken/missing native config: stay silent, never crash the isolate.
  }
}

Map<String, String> _stringMap(Map<String, dynamic> data) {
  final out = <String, String>{};
  data.forEach((key, value) {
    if (value != null) out[key] = value.toString();
  });
  return out;
}

/// Crash-safe FCM wiring.
///
/// EVERY Firebase/plugin call runs inside try/catch: a missing or broken
/// native config (no `google-services.json` wiring yet — Task 4) can NEVER
/// crash startup; the app simply runs push-less. Network sync never throws
/// either — all failures are logged and swallowed.
///
/// Construction is plugin-free on purpose: merely watching
/// [pushServiceProvider] (which [authStoreProvider] does) must never touch
/// native code, so widget tests stay green. `FirebaseMessaging.instance` is
/// resolved lazily inside guarded helpers only.
class PushService {
  final ApiClient _api;
  final FlutterLocalNotificationsPlugin _local;
  FirebaseMessaging? _messaging;
  Future<void> Function(String route)? _onTap;
  String? _lastToken;

  PushService(
    this._api, {
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? local,
  })  : _messaging = messaging,
        _local = local ?? FlutterLocalNotificationsPlugin();

  /// Lazily resolves the FCM plugin; null when Firebase is unavailable
  /// (tests, missing native config) — callers treat null as "push-less".
  FirebaseMessaging? _msg() {
    if (_messaging != null) return _messaging;
    try {
      return _messaging = FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  /// Full startup wiring. Call once before `runApp`; returns normally even
  /// when Firebase is unavailable. Token `POST /devices` only fires when a
  /// session exists (mirrors `AuthState.isAuthenticated`: non-empty
  /// `accessToken` in secure storage).
  Future<void> init({
    required Future<void> Function(String route) onTap,
  }) async {
    _onTap = onTap;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[push] Firebase unavailable, running push-less: $e');
      return;
    }
    final msg = _msg();
    if (msg == null) {
      debugPrint('[push] messaging unavailable, running push-less');
      return;
    }
    try {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      debugPrint('[push] background handler skipped: $e');
    }
    try {
      await msg.requestPermission();
    } catch (e) {
      debugPrint('[push] permission request failed: $e');
    }
    try {
      await msg.subscribeToTopic(newProductsTopic);
    } catch (e) {
      debugPrint('[push] subscribe failed: $e');
    }
    try {
      await _initLocalBanners();
    } catch (e) {
      debugPrint('[push] local banners unavailable: $e');
    }
    try {
      msg.onTokenRefresh.listen(
        (token) => registerToken(token: token),
        onError: (Object e) => debugPrint('[push] token refresh error: $e'),
      );
    } catch (e) {
      debugPrint('[push] token-refresh listener skipped: $e');
    }
    try {
      msg.onMessage.listen(_showForegroundBanner);
    } catch (e) {
      debugPrint('[push] onMessage skipped: $e');
    }
    try {
      msg.onMessageOpenedApp.listen(_routeMessage);
    } catch (e) {
      debugPrint('[push] onMessageOpenedApp skipped: $e');
    }
    try {
      final initial = await msg.getInitialMessage();
      if (initial != null) _routeMessage(initial);
    } catch (e) {
      debugPrint('[push] initial message skipped: $e');
    }
    try {
      await registerToken();
    } catch (e) {
      debugPrint('[push] initial register failed: $e');
    }
  }

  Future<void> _initLocalBanners() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) {
          _tap(route);
        }
      },
    );
    const channel = AndroidNotificationChannel(
      pushChannelId,
      'Shop updates',
      description: 'New products and order updates',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showForegroundBanner(RemoteMessage message) async {
    try {
      final route = routeForPush(_stringMap(message.data));
      final notification = message.notification;
      await _local.show(
        message.messageId.hashCode,
        notification?.title ?? 'Orvix Shop',
        notification?.body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            pushChannelId,
            'Shop updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: route,
      );
    } catch (e) {
      debugPrint('[push] banner failed: $e');
    }
  }

  void _routeMessage(RemoteMessage message) {
    try {
      final route = routeForPush(_stringMap(message.data));
      if (route != null) _tap(route);
    } catch (e) {
      debugPrint('[push] tap routing failed: $e');
    }
  }

  Future<void> _tap(String route) async {
    try {
      await _onTap?.call(route);
    } catch (e) {
      debugPrint('[push] onTap failed: $e');
    }
  }

  Future<bool> _loggedIn() async {
    try {
      final token = await _api.storage.read(key: 'accessToken');
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// `POST /devices {token}` — no-op unless logged in and the token looks
  /// backend-valid (zod `min(10)`). Never throws, never touches Firebase
  /// when an explicit [token] is supplied.
  Future<void> registerToken({String? token}) async {
    try {
      if (!await _loggedIn()) return;
      final t = token ?? await _msg()?.getToken();
      if (t == null || t.length < 10) return;
      _lastToken = t;
      try {
        await _api.storage.write(key: 'fcmToken', value: t);
      } catch (_) {}
      await _api.dio.post<dynamic>(
        '/devices',
        data: <String, dynamic>{'token': t},
      );
    } catch (e) {
      debugPrint('[push] register failed: $e');
    }
  }

  /// `DELETE /devices {token}` for the logout path. Must run BEFORE auth
  /// storage is cleared (endpoint is authed). Never throws.
  Future<void> unregister([String? token]) async {
    try {
      var t = token ?? _lastToken;
      if (t == null || t.isEmpty) {
        try {
          t = await _api.storage.read(key: 'fcmToken');
        } catch (_) {
          t = null;
        }
      }
      if (t == null || t.isEmpty) {
        try {
          t = await _msg()?.getToken();
        } catch (_) {
          t = null;
        }
      }
      if (t == null || t.length < 10) return;
      await _api.dio.delete<dynamic>(
        '/devices',
        data: <String, dynamic>{'token': t},
      );
    } catch (e) {
      debugPrint('[push] unregister failed: $e');
    } finally {
      _lastToken = null;
      try {
        await _api.storage.delete(key: 'fcmToken');
      } catch (_) {}
    }
  }
}

/// Riverpod accessor; features `ref.watch(pushServiceProvider)` then call
/// `registerToken()` / `unregister()`. No router dependency (avoids a
/// provider cycle: router → auth → push → api only).
final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref.watch(apiClientProvider));
});

/// App-start entry: `await initPush(onTap: (route) async => ...)` BEFORE
/// `runApp`. Catches everything — a missing/broken native Firebase config
/// logs and returns normally (app works push-less; Task 4 adds config).
Future<void> initPush({
  required Future<void> Function(String route) onTap,
}) async {
  try {
    await PushService(ApiClient()).init(onTap: onTap);
  } catch (e) {
    debugPrint('[push] initPush failed, running push-less: $e');
  }
}
