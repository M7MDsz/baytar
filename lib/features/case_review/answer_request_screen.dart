import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/supabase.dart';
import '../../core/widgets.dart';
import 'info_request.dart';
import 'info_request_card.dart';

/// US-18 (owner side): answer the veterinarian's request; the request then shows as Answered.
class AnswerRequestScreen extends StatefulWidget {
  const AnswerRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<AnswerRequestScreen> createState() => _AnswerRequestScreenState();
}

class _AnswerRequestScreenState extends State<AnswerRequestScreen> {
  final _response = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    if (_response.text.trim().isEmpty) {
      showSnack(context, 'اكتب ردك أولاً', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await db.rpc('answer_info', params: {'p_request': widget.requestId, 'p_response': _response.text});
      if (!mounted) return;
      showSnack(context, 'تم إرسال ردك إلى الطبيب');
      context.pop(true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, {'already_answered': 'تم الرد على هذا الطلب مسبقاً.'}), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('طلب معلومات')),
        body: AsyncView<InfoRequest>(
          load: () async => InfoRequest.fromMap(await db.from('info_requests').select().eq('id', widget.requestId).single()),
          builder: (context, r, _) => ListView(padding: const EdgeInsets.all(16), children: [
            InfoRequestCard(request: r),
            if (r.isOpen) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _response,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'ردك على الطبيب'),
              ),
              const SizedBox(height: 16),
              BusyButton(busy: _busy, onPressed: _send, label: 'إرسال الرد'),
            ],
          ]),
        ),
      );
}
