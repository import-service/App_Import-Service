import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:import_service_app/core/di/injection_container.dart';
import 'package:import_service_app/core/i18n/app_locale.dart';
import 'package:import_service_app/core/i18n/json_strings_service.dart';
import 'package:import_service_app/core/logging/bootstrap_logger.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/core/ui/app_scaffold_messenger_key.dart';
import 'package:import_service_app/presentation/router/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bootstrapLogger();
  await initDependencies();
  await initializeDateFormatting('ru');
  await initializeDateFormatting('zh');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) {
        return MaterialApp.router(
          scaffoldMessengerKey: appScaffoldMessengerKey,
          onGenerateTitle: (_) => sl<JsonStringsService>().appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: locale,
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) {
              return const Locale('ru');
            }
            for (final supported in supportedLocales) {
              if (supported.languageCode == locale.languageCode) {
                return supported;
              }
            }
            return const Locale('ru');
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('zh')],
          routerConfig: appRouter,
        );
      },
    );
  }
}
