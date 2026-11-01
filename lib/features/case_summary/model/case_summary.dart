import 'dart:convert';

/// Sprint 2 shared data model: the AI case summary (US-24) as `vet_case_summary` returns it (US-25, US-27, US-28).
/// Pure data only: no widgets and no network calls.

/// Where a sent case's AI summary stands (`summary_status`). [none] when no summary was requested for the case.
enum SummaryStatus {
  none,
  pending,
  generated,
  notGenerated,
  failed,
  accepted,
  disregarded;

  /// Reads the database value; null and unknown values are [none].
  static SummaryStatus parse(Object? raw) => switch (raw) {
        'pending' => pending,
        'generated' => generated,
        'not_generated' => notGenerated,
        'failed' => failed,
        'accepted' => accepted,
        'disregarded' => disregarded,
        _ => none,
      };

  /// Content exists (and may be shown) only while the summary is generated or accepted, never once disregarded.
  bool get hasContent => this == generated || this == accepted;

  /// A generated summary waits for the veterinarian to accept or disregard it, once.
  bool get awaitingReview => this == generated;

  bool get reviewed => this == accepted || this == disregarded;
}

/// One summary item: a short Arabic phrase and the owner's own words it was taken from.
class SummaryItem {
  const SummaryItem({required this.value, this.quote});

  final String value;

  /// The words in the owner's description that support [value].
  final String? quote;

  /// Reads `{value, quote}`. Anything else, or a blank value, is null.
  static SummaryItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final value = raw['value'];
    if (value is! String || value.trim().isEmpty) return null;
    final quote = raw['quote'];
    return SummaryItem(
      value: value.trim(),
      quote: quote is String && quote.trim().isNotEmpty ? quote.trim() : null,
    );
  }
}

/// `summary_content`: the owner's description organised by the AI. Advisory, never a diagnosis.
class SummaryContent {
  const SummaryContent({this.chiefComplaint, this.duration, this.onset, this.affectedArea, this.symptoms = const []});

  final SummaryItem? chiefComplaint;
  final SummaryItem? duration;
  final SummaryItem? onset;
  final SummaryItem? affectedArea;
  final List<SummaryItem> symptoms;

  bool get isEmpty =>
      chiefComplaint == null && duration == null && onset == null && affectedArea == null && symptoms.isEmpty;

  /// Null when [raw] is not a JSON object (pending, failed and disregarded summaries have no content).
  static SummaryContent? fromJson(Object? raw) {
    final json = raw is String ? _decode(raw) : raw;
    if (json is! Map) return null;
    final symptoms = json['symptoms'];
    return SummaryContent(
      chiefComplaint: SummaryItem.fromJson(json['chief_complaint']),
      duration: SummaryItem.fromJson(json['duration']),
      onset: SummaryItem.fromJson(json['onset']),
      affectedArea: SummaryItem.fromJson(json['affected_area']),
      symptoms: [for (final s in symptoms is List ? symptoms : const []) ?SummaryItem.fromJson(s)],
    );
  }

  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
