import 'package:baytar/features/ratings/rating.dart';
import 'package:baytar/features/ratings/rating_section.dart';
import 'package:baytar/features/ratings/star_rating.dart';
import 'package:baytar/features/vets/vet_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// US-38 Rate a Consultation.
void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  Widget host(Widget child) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  group('the rating state', () {
    test('reads every state, and anything unknown is unavailable', () {
      expect(RatingState.parse('available'), RatingState.available);
      expect(RatingState.parse('rated'), RatingState.rated);
      expect(RatingState.parse('closed'), RatingState.closed);
      expect(RatingState.parse(null), RatingState.unavailable);
    });

    test('a saved rating reads back with its stars and comment', () {
      final r = ConsultationRating.fromMap({
        'state': 'rated',
        'stars': 4,
        'comment': 'شرحت الحالة بوضوح',
        'rated_at': '2026-11-12T18:00:00Z',
        'closes_at': '2026-11-26T18:00:00Z',
      });
      expect(r.state, RatingState.rated);
      expect(r.stars, 4);
      expect(r.comment, 'شرحت الحالة بوضوح');
    });
  });

  group("the veterinarian's profile", () {
    test('reads the average and the number of ratings', () {
      final v = VetProfile.fromMap({
        'id': 'v1',
        'full_name': 'سارة القحطاني',
        'specialties': ['general'],
        'animal_types': ['cat'],
        'languages': ['ar'],
        'license_number': 'L-100',
        'license_expiry': '2027-11-01',
        'rating': 4.5,
        'rating_count': 12,
      });
      expect(v.rating, 4.5);
      expect(v.ratingCount, 12);
    });

    test('the count reads naturally in Arabic', () {
      expect(ratingCountLabel(1), 'تقييم واحد');
      expect(ratingCountLabel(2), 'تقييمان');
      expect(ratingCountLabel(3), '٣ تقييمات');
      expect(ratingCountLabel(12), '١٢ تقييماً');
    });

    test('a comment carries only the first name', () {
      final r = VetReview.fromMap({'stars': 5, 'comment': 'ممتازة', 'owner_first_name': 'محمد', 'rated_at': '2026-11-12T18:00:00Z'});
      expect(r.ownerFirstName, 'محمد');
    });
  });

  testWidgets('stars are chosen by tapping', (tester) async {
    var value = 0;
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (context, setState) => StarRatingInput(value: value, onChanged: (v) => setState(() => value = v)),
    )));
    await tester.tap(find.byTooltip('٤ من ٥'));
    await tester.pumpAndSettle();
    expect(value, 4);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
  });

  testWidgets('the owner rates once, with a comment, and then sees their rating', (tester) async {
    var state = const ConsultationRating(state: RatingState.available, closesAt: null);
    final sent = <(int, String)>[];
    await tester.pumpWidget(host(RatingSection(
      appointmentId: 'a1',
      load: () async => state,
      submit: (stars, comment) async {
        sent.add((stars, comment));
        state = ConsultationRating(state: RatingState.rated, stars: stars, comment: comment.trim());
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('كيف كانت الاستشارة؟'), findsOneWidget);

    await tester.tap(find.text('إرسال التقييم'));
    await tester.pump();
    expect(sent, isEmpty, reason: 'no stars chosen yet');

    await tester.tap(find.byTooltip('٥ من ٥'));
    await tester.enterText(find.byType(TextField), 'شرحت الحالة بوضوح');
    await tester.tap(find.text('إرسال التقييم'));
    await tester.pumpAndSettle();
    expect(sent, [(5, 'شرحت الحالة بوضوح')]);
    expect(find.text('تقييمك'), findsOneWidget);
    expect(find.text('إرسال التقييم'), findsNothing, reason: 'a consultation is rated only once');
  });

  testWidgets('after 14 days the rating option is no longer available', (tester) async {
    await tester.pumpWidget(host(RatingSection(
      appointmentId: 'a1',
      load: () async => const ConsultationRating(state: RatingState.closed),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('انتهت مدة تقييم'), findsOneWidget);
    expect(find.byType(StarRatingInput), findsNothing);
  });

  testWidgets('a cancelled or undocumented consultation shows no rating at all', (tester) async {
    await tester.pumpWidget(host(RatingSection(
      appointmentId: 'a1',
      load: () async => const ConsultationRating(state: RatingState.unavailable),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(StarRatingInput), findsNothing);
    expect(find.textContaining('تقييم'), findsNothing);
  });
}
