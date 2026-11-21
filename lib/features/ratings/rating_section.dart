import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/widgets.dart';
import 'rating.dart';
import 'ratings_repository.dart';
import 'star_rating.dart';

/// US-38 Rate a Consultation, on the owner's outcome (US-16) and consultation record (US-23): 1 to 5 stars and an
/// optional comment, once, within 14 days of a consultation whose outcome is documented. Afterwards it shows the
/// owner's own rating; after 14 days it says the rating has closed.
class RatingSection extends StatefulWidget {
  const RatingSection({super.key, required this.appointmentId, this.load, this.submit});

  final String appointmentId;

  /// For tests; the ratings repository by default.
  final Future<ConsultationRating?> Function()? load;
  final Future<void> Function(int stars, String comment)? submit;

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection> {
  late Future<ConsultationRating?> _rating = _fetch();
  final _comment = TextEditingController();
  int _stars = 0;
  bool _busy = false;

  Future<ConsultationRating?> _fetch() => widget.load?.call() ?? RatingsRepository().mine(widget.appointmentId);

  Future<void> _send() async {
    if (_stars == 0) {
      showSnack(context, 'اختر عدد النجوم أولاً.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final submit = widget.submit ?? (s, c) => RatingsRepository().rate(widget.appointmentId, s, c);
      await submit(_stars, _comment.text);
      if (!mounted) return;
      showSnack(context, 'شكراً، وصل تقييمك.');
      setState(() => _rating = _fetch());
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, ratingErrors), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ConsultationRating?>(
        future: _rating,
        builder: (context, snap) {
          final r = snap.data;
          if (r == null || r.state == RatingState.unavailable) return const SizedBox.shrink();
          final text = Theme.of(context).textTheme;
          return AnimatedSize(
            duration: const Duration(milliseconds: 260),
            alignment: Alignment.topCenter,
            child: switch (r.state) {
              RatingState.rated => SectionCard(
                  title: 'تقييمك',
                  icon: Icons.star_outline_rounded,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    StarRow(r.stars ?? 0, size: 26),
                    if ((r.comment ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(r.comment!, style: text.bodyLarge),
                    ],
                    if (r.ratedAt != null) ...[
                      const SizedBox(height: 6),
                      Text('قيّمتها يوم ${formatDay(r.ratedAt!)}', style: text.bodySmall),
                    ],
                  ]),
                ),
              RatingState.closed => const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: NoticeBanner('انتهت مدة تقييم هذه الاستشارة (١٤ يوماً بعدها).', tone: Tone.neutral,
                      icon: Icons.star_border_rounded),
                ),
              _ => SectionCard(
                  title: 'كيف كانت الاستشارة؟',
                  icon: Icons.star_outline_rounded,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('يساعد تقييمك المالكين الآخرين على اختيار طبيبهم.', style: text.bodyMedium!.copyWith(color: Palette.muted)),
                    const SizedBox(height: 8),
                    Center(child: StarRatingInput(value: _stars, onChanged: (v) => setState(() => _stars = v))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _comment,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: maxRatingComment,
                      decoration: const InputDecoration(labelText: 'تعليق (اختياري)', hintText: 'يظهر في ملف الطبيب باسمك الأول فقط'),
                    ),
                    const SizedBox(height: 4),
                    BusyButton(busy: _busy, onPressed: _send, label: 'إرسال التقييم'),
                    if (r.closesAt != null) ...[
                      const SizedBox(height: 6),
                      Text('متاح حتى ${formatDay(r.closesAt!)}، مرة واحدة.', textAlign: TextAlign.center, style: text.bodySmall),
                    ],
                  ]),
                ),
            },
          );
        },
      );
}
