import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../app/router.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';

bool _listening = false;

/// US-35: saves this device's push token after sign-in and opens the related page when a push is tapped.
/// Needs android/app/google-services.json (see README); without it the app runs and only in-app notifications work.
Future<void> registerForPush(Profile profile) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Push notifications are off: Firebase is not configured ($e)');
    return;
  }
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  // getToken/onTokenRefresh are deprecated in favour of installation-ID "direct send", but the
  // push-dispatch function sends with FCM HTTP v1 device tokens, so we keep them on purpose.
  // ignore: deprecated_member_use
  final token = await messaging.getToken();
  if (token != null) await _saveToken(profile.id, token);

  if (_listening) return;
  _listening = true;
  // ignore: deprecated_member_use
  messaging.onTokenRefresh.listen((t) {
    final uid = currentUserId;
    if (uid != null) _saveToken(uid, t);
  });
  FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data['route'] as String?));
  final initial = await messaging.getInitialMessage();
  if (initial != null) _open(initial.data['route'] as String?);
}

Future<void> _saveToken(String userId, String token) =>
    db.from('profiles').update({'fcm_token': token}).eq('id', userId);

void _open(String? route) {
  if (route != null && route.startsWith('/')) appRouter.push(route);
}
