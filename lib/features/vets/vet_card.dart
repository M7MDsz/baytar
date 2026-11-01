import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/catalog.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'vet_summary.dart';

/// Hero tag shared by the vet's avatar in the list and on the profile.
String vetAvatarTag(String vetId) => 'vet-avatar-$vetId';

/// Bold name followed by a small green «موثّق» check. Every listed veterinarian is verified.
class VerifiedName extends StatelessWidget {
  const VerifiedName(this.name, {super.key, this.style, this.center = false});

  final String name;
  final TextStyle? style;
  final bool center;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: name),
          const WidgetSpan(child: SizedBox(width: 6)),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              message: 'موثّق',
              child: Semantics(
                label: 'موثّق',
                child: const Icon(Icons.verified_rounded, size: 18, color: Palette.success),
              ),
            ),
          ),
        ]),
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: style ?? Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
      );
}

/// Soft chip with the nearest free time, or a grey chip when there is none.
class NextSlotChip extends StatelessWidget {
  const NextSlotChip(this.nextAvailable, {super.key});

  final DateTime? nextAvailable;

  @override
  Widget build(BuildContext context) {
    final free = nextAvailable != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: free ? Palette.successSoft : Palette.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(free ? Icons.event_available_rounded : Icons.event_busy_rounded, size: 16, color: free ? Palette.success : Palette.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            free ? 'أقرب موعد: ${formatDayTime(nextAvailable!)}' : 'لا توجد مواعيد متاحة',
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: free ? Palette.success : Palette.muted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ]),
    );
  }
}

/// Vet list card in the Vetster manner: large avatar, verified name, specialty line,
/// a two-line bio excerpt when the list provides one, and the nearest free time.
class VetCard extends StatelessWidget {
  const VetCard(this.v, {super.key});

  final VetSummary v;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push('/vets/${v.id}'),
      shadow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 12, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(tag: vetAvatarTag(v.id), child: DoctorAvatar(v.gender, radius: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              VerifiedName(v.fullName),
              const SizedBox(height: 2),
              Text(labelList(specialtyLabels, v.specialties), style: text.bodyMedium!.copyWith(color: Palette.muted)),
              // A rating line (US-38, Sprint 3) slots in here once ratings exist.
            ]),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 22),
            child: Icon(Icons.chevron_right_rounded, color: Palette.muted),
          ),
        ]),
        if ((v.bio ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            v.bio!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium!.copyWith(color: Palette.muted),
          ),
        ],
        const SizedBox(height: 14),
        NextSlotChip(v.nextAvailable),
      ]),
    );
  }
}
