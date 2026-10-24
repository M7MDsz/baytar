import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';

/// US-35: in-app notification list, newest first, live through Supabase Realtime.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(BuildContext context, Map<String, dynamic> n) async {
    if (n['read_at'] == null) {
      await db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', n['id'] as String);
    }
    final route = n['route'] as String?;
    if (route != null && context.mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final stream = db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUserId!)
        .order('created_at', ascending: false)
        .limit(100);
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(icon: Icons.cloud_off, message: 'تعذر تحميل الإشعارات.');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const EmptyState(icon: Icons.notifications_none, message: 'لا توجد إشعارات.');
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final unread = n['read_at'] == null;
              return ListTile(
                tileColor: unread ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
                leading: Icon(unread ? Icons.notifications_active : Icons.notifications_none),
                title: Text(n['title'] as String, style: TextStyle(fontWeight: unread ? FontWeight.bold : null)),
                subtitle: Text('${n['body']}\n${formatDayTime(parseTs(n['created_at']))}'),
                isThreeLine: true,
                onTap: () => _open(context, n),
              );
            },
          );
        },
      ),
    );
  }
}
