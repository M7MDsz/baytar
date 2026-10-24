import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalog.dart';
import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import '../consultation/consultation_room_screen.dart';

/// Path of the outcome form (US-20), opened when the veterinarian ends the consultation.
String outcomeFormPath(String appointmentId) => '/vet/appointments/$appointmentId/outcome';

/// US-19: the veterinarian's video room with the case panel and an End action that records the end time.
class VetConsultationScreen extends StatelessWidget {
  const VetConsultationScreen({super.key, required this.appointmentId});

  final String appointmentId;

  Future<void> _end(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مغادرة الاستشارة'),
        content: const Text('هل انتهت الاستشارة؟ عند الإنهاء يُسجّل وقت الانتهاء وتنتقل لتوثيق النتيجة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'leave'), child: const Text('مغادرة مؤقتة')),
          FilledButton(onPressed: () => Navigator.pop(context, 'end'), child: const Text('إنهاء الاستشارة')),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice != 'end') {
      context.pop();
      return;
    }
    try {
      await db.rpc('end_consultation', params: {'p_appointment': appointmentId});
      if (context.mounted) context.pushReplacement(outcomeFormPath(appointmentId));
    } catch (e) {
      if (context.mounted) {
        showSnack(context, friendlyError(e, {'not_in_progress': 'هذه الاستشارة غير جارية.'}), error: true);
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) => ConsultationRoomScreen(
        appointmentId: appointmentId,
        endLabel: 'إنهاء',
        onEnd: _end,
        panelBuilder: (_) => _CasePanel(appointmentId: appointmentId),
      );
}

class _CasePanel extends StatelessWidget {
  const _CasePanel({required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: AsyncView<Map<String, dynamic>?>(
          load: () async =>
              await db.rpc('consultation_case_panel', params: {'p_appointment': appointmentId}) as Map<String, dynamic>?,
          builder: (context, panel, _) {
            if (panel == null) return const EmptyState(icon: Icons.lock_outline, message: 'لا يمكنك عرض هذه الحالة.');
            final animal = panel['animal'] as Map<String, dynamic>;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('${animal['name']} · ${label(speciesLabels, animal['species'] as String?)}',
                  style: Theme.of(context).textTheme.titleLarge),
              InfoRow('رقم الحالة', panel['case_number'] as String?),
              InfoRow('السلالة', animal['breed'] as String?),
              InfoRow('الجنس', label(sexLabels, animal['sex'] as String?)),
              InfoRow('العمر', animal['age_years'] == null ? animal['birth_date'] as String? : '${animal['age_years']} سنة'),
              InfoRow('الوزن', animal['weight_kg'] == null ? null : '${animal['weight_kg']} كجم'),
              InfoRow('حالات معروفة', animal['conditions'] as String?),
              InfoRow('الحساسية', animal['allergies'] as String?),
              const SectionTitle('وصف المالك'),
              Text((panel['description'] as String?) ?? 'لا يوجد وصف مكتوب.'),
              if (panel['has_voice'] == true)
                const Padding(padding: EdgeInsets.only(top: 8), child: Text('أرفق المالك وصفاً صوتياً (متاح في صفحة الحالة).')),
            ]);
          },
        ),
      );
}
