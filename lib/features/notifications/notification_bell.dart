import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/supabase.dart';

/// Bell for the header of the tab screens, with a live count of unread notifications.
/// Opens the notifications list (US-35) as a pushed page.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  // Same live query as the notifications list; only unread rows are counted.
  late final Stream<List<Map<String, dynamic>>> _stream = db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', currentUserId!)
      .order('created_at', ascending: false)
      .limit(100);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          final unread = snap.data?.where((n) => n['read_at'] == null).length ?? 0;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: IconButton(
              tooltip: 'الإشعارات',
              onPressed: () => context.push('/notifications'),
              style: IconButton.styleFrom(
                backgroundColor: Palette.surface,
                side: const BorderSide(color: Palette.line),
              ),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 9 ? '9+' : '$unread'),
                backgroundColor: Palette.danger,
                textColor: Colors.white,
                offset: const Offset(6, -6),
                child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_outlined),
              ),
            ),
          );
        },
      );
}
