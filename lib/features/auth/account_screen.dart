import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../notifications/notification_bell.dart';
import 'auth_repository.dart';

/// Account tab for every role: details, push setting (US-35) and sign out (US-30).
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool? _push;

  Future<void> _setPush(bool value) async {
    setState(() => _push = value);
    try {
      await db.from('profiles').update({'push_enabled': value}).eq('id', currentUserId!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _push = !value);
      showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _signOut() async {
    final ok = await confirmDialog(context, title: 'تسجيل الخروج', message: 'هل تريد تسجيل الخروج من بيطار؟', confirmLabel: 'خروج');
    if (ok) await AuthRepository().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final p = Session.instance.profile;
    const roleNames = {UserRole.owner: 'مالك حيوان', UserRole.vet: 'طبيب بيطري', UserRole.admin: 'مشرف'};
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي'), actions: const [NotificationBell()]),
      body: ListView(padding: pagePadding(context), children: [
        if (p != null) ...[
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              NameAvatar(p.fullName, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.fullName, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  StatusPill(roleNames[p.role]!, tone: Tone.brand),
                ]),
              ),
            ]),
          ),
          InfoCard(children: [
            InfoRow('الاسم', p.fullName),
            InfoRow('البريد', p.email),
            InfoRow('الجوال', p.mobile),
            InfoRow('نوع الحساب', roleNames[p.role]),
          ]),
        ],
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SwitchListTile(
            secondary: const IconTile(Icons.notifications_active_outlined, size: 40),
            title: const Text('الإشعارات الفورية'),
            subtitle: const Text('عند إيقافها تبقى الإشعارات ظاهرة داخل التطبيق'),
            value: _push ?? p?.pushEnabled ?? true,
            onChanged: _setPush,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _signOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4), width: 1.2),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
      ]),
    );
  }
}
