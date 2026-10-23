/// Fixed lists shared by animal profiles, veterinarian registration and filters.
/// Codes are stored in the database; labels are shown in the app.
library;

const speciesLabels = <String, String>{
  'cat': 'قطة',
  'dog': 'كلب',
  'bird': 'طائر',
  'horse': 'خيل',
  'camel': 'إبل',
  'sheep_goat': 'أغنام وماعز',
  'cattle': 'أبقار',
  'other': 'أخرى',
};

const specialtyLabels = <String, String>{
  'general': 'طب عام',
  'small_animals': 'حيوانات أليفة',
  'equine': 'خيول',
  'livestock': 'مواشي',
  'camels': 'إبل',
  'avian': 'طيور',
  'dermatology': 'جلدية',
  'surgery': 'جراحة',
};

const languageLabels = <String, String>{
  'ar': 'العربية',
  'en': 'English',
  'ur': 'اردو',
};

const sexLabels = <String, String>{
  'male': 'ذكر',
  'female': 'أنثى',
};

String label(Map<String, String> labels, String? code) => labels[code] ?? code ?? '';

String labelList(Map<String, String> labels, List<String> codes) =>
    codes.map((c) => label(labels, c)).join('، ');
