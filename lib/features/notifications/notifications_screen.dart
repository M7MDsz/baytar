import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
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
          if (!snap.hasData) return const SkeletonList();
          final items = snap.data!;
          if (items.isEmpty) {
            return const EmptyState(icon: Icons.notifications_none_rounded, message: 'لا توجد إشعارات.');
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            for (final n in items)
              Builder(builder: (context) {
                final unread = n['read_at'] == null;
                return ListCard(
                  color: unread ? Palette.juniperSoft.withValues(alpha: 0.55) : Palette.surface,
                  borderColor: unread ? Palette.juniper.withValues(alpha: 0.18) : Palette.line,
                  leading: Stack(clipBehavior: Clip.none, children: [
                    IconTile(
                      unread ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      tone: unread ? Tone.brand : Tone.neutral,
                      size: 44,
                    ),
                    if (unread)
                      PositionedDirectional(
                        top: -2,
                        end: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Palette.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.surface, width: 2),
                          ),
                        ),
                      ),
                  ]),
                  title: n['title'] as String,
                  subtitle: '${n['body']}\n${formatDayTime(parseTs(n['created_at']))}',
                  trailing: const SizedBox.shrink(),
                  onTap: () => _open(context, n),
                );
              }),
          ]);
        },
      ),
    );
  }
}
