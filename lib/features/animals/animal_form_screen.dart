import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/catalog.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/storage.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import 'animal.dart';
import 'animal_photo.dart';
import 'animals_repository.dart';

/// US-01 (create) and US-02 (edit, when [animalId] is given).
class AnimalFormScreen extends StatefulWidget {
  const AnimalFormScreen({super.key, this.animalId});

  final String? animalId;

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _form = GlobalKey<FormState>();
  final _repo = AnimalsRepository();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _conditions = TextEditingController();
  final _allergies = TextEditingController();
  String? _species;
  String? _sex;
  DateTime? _birthDate;
  String? _photoPath;
  File? _newPhoto;
  bool _loading = false;
  bool _saving = false;

  bool get _editing => widget.animalId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _fill(await _repo.byId(widget.animalId!));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(Animal a) {
    _name.text = a.name;
    _breed.text = a.breed ?? '';
    _age.text = a.ageYears?.toString() ?? '';
    _weight.text = a.weightKg?.toString() ?? '';
    _conditions.text = a.conditions ?? '';
    _allergies.text = a.allergies ?? '';
    _species = a.species;
    _sex = a.sex;
    _birthDate = a.birthDate;
    _photoPath = a.photoPath;
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (file == null) return;
    final ext = extensionOf(file.path);
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      if (mounted) showSnack(context, 'الصورة يجب أن تكون JPG أو PNG', error: true);
      return;
    }
    setState(() => _newPhoto = File(file.path));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now,
      firstDate: DateTime(now.year - 60),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String? _trimmed(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    // Every invalid field shows its own message; nothing is saved until all are valid.
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repo.save(
        id: widget.animalId,
        photo: _newPhoto,
        fields: {
          'name': _name.text.trim(),
          'species': _species,
          'sex': _sex,
          'breed': _trimmed(_breed),
          'birth_date': _birthDate == null ? null : formatDate(_birthDate!).replaceAll('/', '-'),
          'age_years': _birthDate == null ? num.parse(_age.text.trim()) : null,
          'weight_kg': _trimmed(_weight) == null ? null : num.parse(_weight.text.trim()),
          'conditions': _trimmed(_conditions),
          'allergies': _trimmed(_allergies),
        },
      );
      if (!mounted) return;
      showSnack(context, _editing ? 'تم حفظ التغييرات' : 'تم حفظ ملف الحيوان');
      context.pop(true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _breed, _age, _weight, _conditions, _allergies]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'تعديل ملف الحيوان' : 'حيوان جديد')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: _newPhoto != null
                        ? CircleAvatar(radius: 44, backgroundImage: FileImage(_newPhoto!))
                        : AnimalPhoto(path: _photoPath, radius: 44),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('صورة الحيوان (اختياري)'),
                ),
                gap,
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: requiredLabel('الاسم')),
                  validator: (v) => requiredText(v, 'اسم الحيوان'),
                ),
                gap,
                DropdownButtonFormField<String>(
                  initialValue: _species,
                  decoration: InputDecoration(labelText: requiredLabel('النوع')),
                  items: [
                    for (final e in speciesLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _species = v),
                  validator: (v) => requiredChoice(v, 'نوع الحيوان'),
                ),
                gap,
                TextFormField(controller: _breed, decoration: const InputDecoration(labelText: 'السلالة')),
                gap,
                FormField<String>(
                  initialValue: _sex,
                  validator: (_) => requiredChoice(_sex, 'الجنس'),
                  builder: (field) => InputDecorator(
                    decoration: InputDecoration(labelText: requiredLabel('الجنس'), errorText: field.errorText),
                    child: SegmentedButton<String>(
                      emptySelectionAllowed: true,
                      segments: [
                        for (final e in sexLabels.entries) ButtonSegment(value: e.key, label: Text(e.value)),
                      ],
                      selected: {?_sex},
                      onSelectionChanged: (s) => setState(() => _sex = s.firstOrNull),
                    ),
                  ),
                ),
                gap,
                FormField<void>(
                  validator: (_) => ageOrBirthDate(age: _age.text, birthDate: _birthDate),
                  builder: (field) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickBirthDate,
                          icon: const Icon(Icons.cake_outlined),
                          label: Text(_birthDate == null ? 'تاريخ الميلاد' : formatDate(_birthDate!)),
                        ),
                      ),
                      if (_birthDate != null)
                        IconButton(
                          tooltip: 'مسح التاريخ',
                          onPressed: () => setState(() => _birthDate = null),
                          icon: const Icon(Icons.close),
                        ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('أو')),
                      Expanded(
                        child: TextFormField(
                          controller: _age,
                          enabled: _birthDate == null,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'العمر بالسنوات'),
                        ),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        field.errorText ?? 'العمر أو تاريخ الميلاد مطلوب *',
                        style: TextStyle(
                          fontSize: 12,
                          color: field.hasError
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]),
                ),
                gap,
                TextFormField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الوزن (كجم)'),
                  validator: (v) => optionalPositiveNumber(v, 'الوزن'),
                ),
                gap,
                TextFormField(
                  controller: _conditions,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'أمراض أو حالات معروفة'),
                ),
                gap,
                TextFormField(controller: _allergies, maxLines: 2, decoration: const InputDecoration(labelText: 'الحساسية')),
                const SizedBox(height: 24),
                BusyButton(busy: _saving, onPressed: _save, label: 'حفظ'),
              ]),
            ),
    );
  }
}
