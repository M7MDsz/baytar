import 'dart:io';

import '../../core/storage.dart';
import '../../core/supabase.dart';
import 'animal.dart';

class AnimalsRepository {
  static const _bucket = 'animal-photos';

  Future<List<Animal>> mine() async {
    final rows = await db.from('animals').select().eq('owner_id', currentUserId!).order('created_at');
    return rows.map(Animal.fromMap).toList();
  }

  Future<Animal> byId(String id) async =>
      Animal.fromMap(await db.from('animals').select().eq('id', id).single());

  /// Creates the animal when [id] is null, otherwise updates it. Uploads [photo] first when given.
  Future<Animal> save({String? id, required Map<String, dynamic> fields, File? photo}) async {
    final values = {...fields};
    if (photo != null) {
      values['photo_path'] = await uploadFile(
        _bucket,
        userFilePath('animals', extensionOf(photo.path)),
        photo,
        contentType: extensionOf(photo.path) == 'png' ? 'image/png' : 'image/jpeg',
      );
    }
    final query = id == null
        ? db.from('animals').insert(values)
        : db.from('animals').update(values).eq('id', id);
    return Animal.fromMap(await query.select().single());
  }

  Future<String> photoUrl(String path) => signedUrl(_bucket, path);
}
