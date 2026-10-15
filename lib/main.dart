import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:idv_map_guides/generated/l10n.dart';
import 'package:idv_map_guides/pages/editors/structures_editor_page.dart';
import 'package:idv_map_guides/pages/editors/world_editor_page.dart';
import 'package:idv_map_guides/pages/entrances_page.dart';
import 'package:idv_map_guides/pages/home_page.dart';
import 'package:idv_map_guides/pages/worlds_page.dart';
import 'package:idv_map_guides/routes.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:toastification/toastification.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const initializeSentry = !kDebugMode;

void main() async {
  if (!initializeSentry) {
    runApp(const MyApp());
  } else {
    const dsn = String.fromEnvironment('SENTRY_DSN');
    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.sendDefaultPii = true;
      options.sampleRate = 1.0;
      options.tracesSampleRate = 1.0;
      options.attachScreenshot = true;
      options.privacy.maskAllText = false;
      options.navigatorKey = navigatorKey;
    }, appRunner: () => runApp(SentryWidget(child: const MyApp())));
  }
}

final editorMode = ValueNotifier<bool>(kDebugMode);

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
          navigatorKey: navigatorKey,
          initialRoute: Routes.home,
          onGenerateRoute: (settings) {
            WidgetBuilder? resolve(RouteSettings settings) {
              switch (settings.name) {
                case Routes.home:
                  return (context) => const HomePage();
                case Routes.entrances:
                  final args = settings.arguments as EntranceFeaturePageArguments?;
                  if (args == null) return null;
                  return (context) => EntranceFeaturePage(arguments: args);
                case Routes.worlds:
                  final args = settings.arguments as WorldListPageArguments?;
                  if (args == null) return null;
                  return (context) => WorldListPage(arguments: args);
                case Routes.editorStructure:
                  if (!editorMode.value) return null;
                  return (context) => const StructuresEditorPage();
                case Routes.editorWorld:
                  if (!editorMode.value) return null;
                  return (context) => const WorldEditorPage();
                default:
                  return null;
              }
            }
            final builder = resolve(settings);
            if (builder == null) {
              return MaterialPageRoute(
                settings: const RouteSettings(name: Routes.home),
                builder: (context) => const HomePage(),
              );
            }
            return MaterialPageRoute(
              settings: settings,
              builder: builder,
            );
          },
          navigatorObservers: [
            SentryNavigatorObserver(
              setRouteNameAsTransaction: true,
            ),
          ],
        ),
      ),
    );
  }
}
