import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase.dart';

/// Every private bucket keeps a user's files under `<user id>/...`; the storage policies check that prefix.
String userFilePath(String folder, String extension) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final salt = Random().nextInt(1 << 32).toRadixString(16);
  return '$currentUserId/$folder/$stamp-$salt.${extension.toLowerCase()}';
}

Future<String> uploadFile(String bucket, String path, File file, {String? contentType}) async {
  await db.storage.from(bucket).upload(
        path,
        file,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
  return path;
}

Future<String> signedUrl(String bucket, String path) =>
    db.storage.from(bucket).createSignedUrl(path, 60 * 60);

String extensionOf(String filePath) {
  final dot = filePath.lastIndexOf('.');
  return dot < 0 ? '' : filePath.substring(dot + 1).toLowerCase();
}
