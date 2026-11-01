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
            padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
            child: Stack(clipBehavior: Clip.none, children: [
              IconButton(
                tooltip: 'الإشعارات',
                onPressed: () => context.push('/notifications'),
                style: IconButton.styleFrom(
                  backgroundColor: Palette.surface,
                  side: const BorderSide(color: Palette.line),
                ),
                icon: Icon(
                  unread > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                  color: Palette.ink,
                ),
              ),
              if (unread > 0)
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: IgnorePointer(child: _CountBadge(unread)),
                ),
            ]),
          );
        },
      );
}

/// Rose pill with a white ring and Arabic-Indic digits ("٩+" above nine). Pops in when the count changes.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  static const _digits = '٠١٢٣٤٥٦٧٨٩';

  String get _label =>
      count > 9 ? '${_digits[9]}+' : count.toString().split('').map((d) => _digits[int.parse(d)]).join();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(count),
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          height: 20,
          constraints: const BoxConstraints(minWidth: 20),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.alert,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x33E11D48), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Text(
            _label,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.1),
          ),
        ),
      );
}
