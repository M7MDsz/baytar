import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/storage.dart';
import '../../core/widgets.dart';
import 'case_record.dart';
import 'cases_repository.dart';
import 'media_rules.dart';

/// US-05: optional photos and short videos, with preview and remove before submitting.
class MediaAttachmentsField extends StatelessWidget {
  const MediaAttachmentsField({super.key, required this.items, required this.onChanged});

  final List<MediaItem> items;
  final ValueChanged<List<MediaItem>> onChanged;

  Future<void> _add(BuildContext context, {required bool video}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3))
        : await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final ext = extensionOf(file.path);
    final size = await file.length();
    int? seconds;
    if (videoExtensions.contains(ext)) {
      final controller = VideoPlayerController.file(File(file.path));
      try {
        await controller.initialize();
        seconds = controller.value.duration.inSeconds;
      } finally {
        await controller.dispose();
      }
    }
    final reason = mediaRejection(extension: ext, sizeBytes: size, durationSeconds: seconds);
    if (!context.mounted) return;
    if (reason != null) {
      showSnack(context, reason, error: true);
      return;
    }
    onChanged([...items, MediaItem(kind: mediaKind(ext), sizeBytes: size, localPath: file.path, durationSeconds: seconds)]);
  }

  void _preview(BuildContext context, MediaItem m) => showDialog<void>(
        context: context,
        builder: (_) => Dialog(child: _Preview(item: m)),
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in items)
            InputChip(
              avatar: Icon(m.isVideo ? Icons.movie_outlined : Icons.image_outlined),
              label: Text('${m.isVideo ? 'فيديو' : 'صورة'} · ${(m.sizeBytes / 1048576).toStringAsFixed(1)} م.ب'),
              onPressed: () => _preview(context, m),
              onDeleted: () => onChanged([...items]..remove(m)),
              deleteButtonTooltipMessage: 'إزالة',
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _add(context, video: false),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('صورة'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _add(context, video: true),
              icon: const Icon(Icons.video_call_outlined),
              label: const Text('فيديو'),
            ),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('اختياري · JPG أو PNG أو MP4 حتى 3 دقائق · 30 ميجابايت كحد أقصى', style: TextStyle(fontSize: 12)),
        ),
      ]);
}

class _Preview extends StatefulWidget {
  const _Preview({required this.item});

  final MediaItem item;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  VideoPlayerController? _video;
  String? _url;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final m = widget.item;
    if (m.remotePath != null) _url = await signedUrl(mediaBucket, m.remotePath!);
    if (m.isVideo) {
      _video = m.localPath != null
          ? VideoPlayerController.file(File(m.localPath!))
          : VideoPlayerController.networkUrl(Uri.parse(_url!));
      await _video!.initialize();
      await _video!.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.item;
    if (m.isVideo) {
      final v = _video;
      if (v == null || !v.value.isInitialized) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
      return AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v));
    }
    if (m.localPath != null) return Image.file(File(m.localPath!));
    if (_url == null) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    return Image.network(_url!);
  }
}
