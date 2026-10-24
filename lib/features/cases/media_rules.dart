/// US-05 attachment rules. Returns an Arabic reason when the file is rejected, otherwise null.
library;

const maxMediaBytes = 30 * 1024 * 1024;
const maxVideoSeconds = 180;
const photoExtensions = {'jpg', 'jpeg', 'png'};
const videoExtensions = {'mp4'};

String? mediaRejection({required String extension, required int sizeBytes, int? durationSeconds}) {
  final ext = extension.toLowerCase();
  if (!photoExtensions.contains(ext) && !videoExtensions.contains(ext)) {
    return 'نوع الملف غير مدعوم. الأنواع المدعومة: صور JPG أو PNG، وفيديو MP4.';
  }
  if (sizeBytes > maxMediaBytes) return 'حجم الملف أكبر من الحد المسموح (30 ميجابايت).';
  if (videoExtensions.contains(ext) && durationSeconds != null && durationSeconds > maxVideoSeconds) {
    return 'مدة الفيديو أطول من 3 دقائق.';
  }
  return null;
}

String mediaKind(String extension) => videoExtensions.contains(extension.toLowerCase()) ? 'video' : 'photo';

String mediaContentType(String extension) => switch (extension.toLowerCase()) {
      'png' => 'image/png',
      'mp4' => 'video/mp4',
      _ => 'image/jpeg',
    };
