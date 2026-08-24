import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:idv_map_guides/bloc/map_cubit.dart';
import 'package:idv_map_guides/bloc/setting_cubit.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/generated/rust/frb_generated.dart';
import 'package:idv_map_guides/pages/home_page.dart';
import 'package:idv_map_guides/pages/editors/structures_editor.dart';
import 'package:idv_map_guides/routes.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingCubit()),
        BlocProvider(create: (_) => MapCubit()),
      ],
      child: BlocBuilder<SettingCubit, SettingState>(
        builder: (context, state) => SafeArea(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: state.theme,
            locale: state.locale,
            localizationsDelegates: const [
              S.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            onGenerateTitle: (context) => S.of(context).title,
            initialRoute: Routes.editorStructure,
            routes: {
              Routes.home: (context) => const HomePage(),

              Routes.editorStructure: (context) => StructuresEditorPage(),
            },
          ),
        ),
      ),
    );
  }
}
