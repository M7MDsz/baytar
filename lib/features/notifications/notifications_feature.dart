import 'package:go_router/go_router.dart';

import '../../app/feature.dart';
import 'notifications_screen.dart';
import 'push_service.dart';

/// US-35. Opened from the bell in the header of every tab screen (see notification_bell.dart).
final notificationsFeature = Feature(
  routes: [
    GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
  ],
  onSignedIn: registerForPush,
);
