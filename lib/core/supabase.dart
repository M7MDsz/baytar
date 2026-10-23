import 'package:supabase_flutter/supabase_flutter.dart';

/// Values come from `--dart-define-from-file=env.json` (see README). Never hard-code keys.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> initSupabase() async {
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError('Missing SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY. Run with --dart-define-from-file=env.json');
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
}

SupabaseClient get db => Supabase.instance.client;

String? get currentUserId => db.auth.currentUser?.id;
