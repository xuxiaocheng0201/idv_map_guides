import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/pages/editors/structures_editor_page.dart';
import 'package:idv_map_guides/pages/editors/world_editor_page.dart';
import 'package:idv_map_guides/pages/entrances_page.dart';
import 'package:idv_map_guides/pages/home_page.dart';
import 'package:idv_map_guides/routes.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:toastification/toastification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    runApp(const MyApp());
  } else {
    const dsn = String.fromEnvironment('SENTRY_DSN');
    await SentryFlutter.init((options) {
        options.dsn = dsn;
        options.sendDefaultPii = false;
        options.sampleRate = 1.0;
        options.replay.sessionSampleRate = 0.1;
        options.replay.onErrorSampleRate = 1.0;
      },
      appRunner: () => runApp(SentryWidget(child: const MyApp())),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: SafeArea(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            S.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          onGenerateTitle: (context) => S.of(context).title,
          initialRoute: Routes.home,
          routes: {
            Routes.home: (context) => const HomePage(),
            Routes.entrances: (context) => const EntranceFeaturePage(),

            if (kDebugMode) Routes.editorStructure: (context) => StructuresEditorPage(),
            if (kDebugMode) Routes.editorWorld: (context) => WorldEditorPage(),
          },
        ),
      ),
    );
  }
}
