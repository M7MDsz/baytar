import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/session.dart';
import 'features.dart';
import 'router.dart';
import 'theme.dart';

class BaytarApp extends StatefulWidget {
  const BaytarApp({super.key});

  @override
  State<BaytarApp> createState() => _BaytarAppState();
}

class _BaytarAppState extends State<BaytarApp> {
  @override
  void initState() {
    super.initState();
    final session = Session.instance;
    session.onSignedIn.addAll(features.map((f) => f.onSignedIn).nonNulls);
    appRouter = buildRouter(features);
    session.start();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'بيطار',
        debugShowCheckedModeBanner: false,
        // Arabic first: the whole app is right-to-left.
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        routerConfig: appRouter,
      );
}
