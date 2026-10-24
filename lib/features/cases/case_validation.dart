/// Items still missing before a case can be sent (US-03 description rule, used by US-07 on submit).
/// A case needs one animal and a written or a voice description.
List<String> missingForSubmit({required String? animalId, required String? description, required bool hasVoice}) => [
      if (animalId == null) 'الحيوان',
      if ((description == null || description.trim().isEmpty) && !hasVoice) 'وصف الحالة (مكتوب أو صوتي)',
    ];
