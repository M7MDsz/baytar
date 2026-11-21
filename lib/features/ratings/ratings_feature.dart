import '../../app/feature.dart';
import 'rating_section.dart';

/// US-38. The owner rates a consultation on its outcome (US-16) and its record (US-23); the section shows nothing
/// until the outcome is documented, and only the owner of the consultation sees it.
final ratingsFeature = Feature(
  consultationSections: [
    ConsultationSection(order: 20, builder: (_, appointmentId) => RatingSection(appointmentId: appointmentId)),
  ],
);
