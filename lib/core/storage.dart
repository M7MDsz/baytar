import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase.dart';

/// Every private bucket keeps a user's files under `<user id>/...`; the storage policies check that prefix.
String userFilePath(String folder, String extension) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  // 2^32 as a literal: on the web `1 << 32` is 0 (JavaScript shifts are 32-bit) and nextInt(0) throws.
  final salt = Random().nextInt(0x100000000).toRadixString(16);
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

Future<String> uploadBytes(String bucket, String path, Uint8List bytes, {String? contentType}) async {
  await db.storage.from(bucket).uploadBinary(
        path,
        bytes,
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
