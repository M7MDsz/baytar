import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';

/// The veterinarian's verification status (US-31/US-32), or a prompt to finish registration.
class VetStatusScreen extends StatelessWidget {
  const VetStatusScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ملفي المهني')),
        body: AsyncView<Map<String, dynamic>?>(
          load: () => db.from('vet_profiles').select().eq('id', currentUserId!).maybeSingle(),
          builder: (context, v, _) {
            if (v == null) {
              return ListView(children: [
                const SizedBox(height: 100),
                EmptyState(
                  icon: Icons.badge_outlined,
                  message: 'لم تُرسل بيانات ترخيصك بعد.',
                  action: FilledButton(
                    onPressed: () => context.push('/vet/profile/complete'),
                    child: const Text('إكمال التسجيل'),
                  ),
                ),
              ]);
            }
            final status = v['status'] as String;
            final (icon, color, text) = switch (status) {
              'verified' => (Icons.verified, Colors.green, 'موثّق · يمكنك نشر المواعيد'),
              'rejected' => (Icons.cancel_outlined, Colors.red, 'مرفوض'),
              'license_expired' => (Icons.event_busy, Colors.orange, 'انتهى الترخيص'),
              _ => (Icons.hourglass_top, Colors.blueGrey, 'بانتظار التحقق'),
            };
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: ListTile(leading: Icon(icon, color: color, size: 36), title: Text(text)),
              ),
              if (status == 'rejected' && v['rejection_reason'] != null)
                Card(child: ListTile(title: const Text('سبب الرفض'), subtitle: Text(v['rejection_reason'] as String))),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('رقم الترخيص', v['license_number'] as String),
                    InfoRow('صالح حتى', formatDate(DateTime.parse(v['license_expiry'] as String))),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
}
