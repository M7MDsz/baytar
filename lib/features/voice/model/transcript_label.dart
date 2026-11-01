/// Sprint 2 shared data model: the label of a case's voice transcript (US-36), shown to the owner on the case form
/// and to the veterinarian next to the original description (US-25). Read from the `transcript_label` column.
enum TranscriptLabel {
  /// The case has no recording.
  none,

  /// Written automatically from the recording.
  auto,

  /// Corrected by the owner.
  owner,

  /// The recording is being turned into text.
  pending,

  /// No transcript: the case has the recording only.
  unavailable;

  /// Reads the database value; null and unknown values are [none].
  static TranscriptLabel parse(Object? raw) => switch (raw) {
        'auto' => auto,
        'owner' => owner,
        'pending' => pending,
        'unavailable' => unavailable,
        _ => none,
      };

  /// True when there is a transcript to read.
  bool get hasText => this == auto || this == owner;

  /// The Arabic label shown above the transcript.
  String get text => switch (this) {
        auto => 'نص تلقائي',
        owner => 'عدّله المالك',
        pending => 'جارٍ تحويل الصوت إلى نص…',
        unavailable => 'النص غير متاح',
        none => '',
      };
}
