import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../notifications/notification_bell.dart';

/// The veterinarian's verification status (US-31/US-32), or a prompt to finish registration.
class VetStatusScreen extends StatelessWidget {
  const VetStatusScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ملفي المهني'), actions: const [NotificationBell()]),
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
            final (icon, tone, text) = switch (status) {
              'verified' => (Icons.verified, Tone.success, 'موثّق · يمكنك نشر المواعيد'),
              'rejected' => (Icons.cancel_outlined, Tone.danger, 'مرفوض'),
              'license_expired' => (Icons.event_busy, Tone.accent, 'انتهى الترخيص'),
              _ => (Icons.hourglass_top, Tone.neutral, 'بانتظار التحقق'),
            };
            final (soft, strong) = toneColors(tone);
            final textTheme = Theme.of(context).textTheme;
            return ListView(padding: pagePadding(context), children: [
              AppCard(
                color: soft,
                borderColor: soft,
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(icon, color: strong, size: 36),
                  ),
                  const SizedBox(height: 14),
                  Text(text, textAlign: TextAlign.center, style: textTheme.titleLarge!.copyWith(color: strong)),
                ]),
              ),
              if (status == 'rejected' && v['rejection_reason'] != null)
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سبب الرفض', style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(v['rejection_reason'] as String, style: textTheme.bodyMedium),
                  ]),
                ),
              InfoCard(children: [
                InfoRow('رقم الترخيص', v['license_number'] as String),
                InfoRow('صالح حتى', formatDate(DateTime.parse(v['license_expiry'] as String))),
              ]),
            ]);
          },
        ),
      );
}
