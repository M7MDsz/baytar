import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/session.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
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
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (p != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                InfoRow('الاسم', p.fullName),
                InfoRow('البريد', p.email),
                InfoRow('الجوال', p.mobile),
                InfoRow('نوع الحساب', roleNames[p.role]),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            title: const Text('الإشعارات الفورية'),
            subtitle: const Text('عند إيقافها تبقى الإشعارات ظاهرة داخل التطبيق'),
            value: _push ?? p?.pushEnabled ?? true,
            onChanged: _setPush,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
      ]),
    );
  }
}
