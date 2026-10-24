import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/storage.dart';
import '../cases/case_record.dart';
import '../cases/cases_repository.dart';

/// Read-only thumbnails of a case's photos and videos; tap to open full size.
class MediaGallery extends StatelessWidget {
  const MediaGallery({super.key, required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('لا توجد مرفقات.');
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final m in items)
        FutureBuilder<String>(
          future: signedUrl(mediaBucket, m.remotePath!),
          builder: (context, snap) => InkWell(
            onTap: snap.hasData
                ? () => showDialog<void>(context: context, builder: (_) => Dialog(child: _Full(item: m, url: snap.data!)))
                : null,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                image: snap.hasData && !m.isVideo
                    ? DecorationImage(image: NetworkImage(snap.data!), fit: BoxFit.cover)
                    : null,
              ),
              child: m.isVideo ? const Icon(Icons.play_circle_outline, size: 40) : null,
            ),
          ),
        ),
    ]);
  }
}

class _Full extends StatefulWidget {
  const _Full({required this.item, required this.url});

  final MediaItem item;
  final String url;

  @override
  State<_Full> createState() => _FullState();
}

class _FullState extends State<_Full> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _video = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _video!.play();
        });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    if (v == null) return Image.network(widget.url);
    if (!v.value.isInitialized) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    return AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v));
  }
}
