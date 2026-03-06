import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';

/// Ponto de entrada do aplicativo. Configura a internacionalização,
/// temas e define a `HomePage` como tela inicial.
void main() {
  // Use a non-const constructor here so the widget can hold mutable state.
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// The currently selected locale for the application. When null,
  /// the system locale will be used.
  Locale? _locale;

  /// Updates the application locale and rebuilds the widget tree.
  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Autonomo App',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [
        Locale('pt'),
        Locale('en'),
        Locale('ja'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      // Pass the callback to HomePage so it can request locale changes.
      home: HomePage(onLocaleChanged: _setLocale),
    );
  }
}
