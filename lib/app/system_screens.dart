import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/logo/baytar-mark.png', width: 120),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ]),
        ),
      );
}

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 12),
            const Text('لا تملك صلاحية لفتح هذه الصفحة.'),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => context.go('/'), child: const Text('العودة للرئيسية')),
          ]),
        ),
      );
}
