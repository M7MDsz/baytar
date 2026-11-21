import 'package:flutter/widgets.dart';

import 'features.dart';

/// Every part's sections for one consultation (see [ConsultationSection]), in display order.
List<Widget> consultationSectionWidgets(BuildContext context, String appointmentId) {
  final sections = features.expand((f) => f.consultationSections).toList()..sort((a, b) => a.order.compareTo(b.order));
  return [for (final s in sections) s.builder(context, appointmentId)];
}
