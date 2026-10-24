import '../../core/formatting.dart';

class InfoRequest {
  const InfoRequest({
    required this.id,
    required this.caseId,
    required this.message,
    required this.status,
    required this.createdAt,
    this.response,
    this.respondedAt,
  });

  final String id;
  final String caseId;
  final String message;

  /// open or answered.
  final String status;
  final DateTime createdAt;
  final String? response;
  final DateTime? respondedAt;

  bool get isOpen => status == 'open';

  factory InfoRequest.fromMap(Map<String, dynamic> m) => InfoRequest(
        id: m['id'] as String,
        caseId: m['case_id'] as String,
        message: m['message'] as String,
        status: m['status'] as String,
        createdAt: parseTs(m['created_at']),
        response: m['response'] as String?,
        respondedAt: parseTsOrNull(m['responded_at']),
      );
}
