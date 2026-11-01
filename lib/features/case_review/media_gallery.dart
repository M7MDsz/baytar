import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme.dart';
import '../../core/storage.dart';
import '../cases/case_record.dart';
import '../cases/cases_repository.dart';

/// Read-only thumbnails of a case's photos and videos; tap to open full size.
class MediaGallery extends StatelessWidget {
  const MediaGallery({super.key, required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('لا توجد مرفقات.', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Palette.muted));
    }
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final m in items)
        FutureBuilder<String>(
          future: signedUrl(mediaBucket, m.remotePath!),
          builder: (context, snap) => InkWell(
            borderRadius: BorderRadius.circular(Radii.tile),
            onTap: snap.hasData
                ? () => showDialog<void>(context: context, builder: (_) => Dialog(child: _Full(item: m, url: snap.data!)))
                : null,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Palette.surfaceMuted,
                borderRadius: BorderRadius.circular(Radii.tile),
                border: Border.all(color: Palette.line),
                image: snap.hasData && !m.isVideo
                    ? DecorationImage(image: NetworkImage(snap.data!), fit: BoxFit.cover)
                    : null,
              ),
              child: m.isVideo
                  ? const Center(
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0x990E2A25),
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                      ),
                    )
                  : null,
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
