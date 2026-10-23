import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase.dart';

enum UserRole { owner, vet, admin }

class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    this.mobile,
    this.pushEnabled = true,
  });

  final String id;
  final UserRole role;
  final String fullName;
  final String email;
  final String? mobile;
  final bool pushEnabled;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        role: UserRole.values.byName(m['role'] as String),
        fullName: m['full_name'] as String,
        email: m['email'] as String,
        mobile: m['mobile'] as String?,
        pushEnabled: (m['push_enabled'] as bool?) ?? true,
      );
}

typedef SignedInHook = Future<void> Function(Profile profile);

/// Who is signed in and with which role. The router listens to it.
class Session extends ChangeNotifier {
  Session._();

  static final instance = Session._();

  /// Features register work to run after every sign-in (for example push registration).
  final List<SignedInHook> onSignedIn = [];

  Profile? profile;
  bool loading = false;
  StreamSubscription<AuthState>? _sub;

  bool get signedIn => db.auth.currentSession != null;

  void start() {
    _sub ??= db.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        profile = null;
        notifyListeners();
      } else if (state.session != null && profile?.id != state.session!.user.id) {
        reload();
      }
    });
    if (signedIn) reload();
  }

  Future<void> reload() async {
    final uid = currentUserId;
    if (uid == null) return;
    loading = true;
    notifyListeners();
    try {
      final row = await db.from('profiles').select().eq('id', uid).maybeSingle();
      profile = row == null ? null : Profile.fromMap(row);
      if (profile != null) {
        for (final hook in onSignedIn) {
          unawaited(hook(profile!).catchError((Object e) => debugPrint('sign-in hook failed: $e')));
        }
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
