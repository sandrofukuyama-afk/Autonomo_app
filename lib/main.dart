import 'dart:async';

import 'package:autonomo_app/data/auth_service.dart';
import 'package:autonomo_app/l10n/app_localizations.dart';
import 'package:autonomo_app/pages/auth_page.dart';
import 'package:autonomo_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dzazwpgjncowkudkdhca.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJIUzI1NiIsInJlZiI6ImR6YXp3cGdqbmNvd2t1ZGtkaGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MDIyODAsImV4cCI6MjA4ODM3ODI4MH0.mQBxjBlgPQpxb5-QyFNhgitM_WOnWlkEzFStYZPr5Pk',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _localeStorageKey = 'app_locale';

  Locale? _locale;
  bool _localeReady = false;
  StreamSubscription<AuthState>? _authSubscription;

  static const List<String> _allowedLanguageCodes = ['pt', 'es', 'en', 'ja'];

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthChanges() {
    _authSubscription = AuthService.instance.authStateChanges.listen((_) async {
      await _syncLocaleFromUserProfile();
    });
  }

  Future<void> _initializeLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_localeStorageKey);

    Locale? initialLocale;
    if (savedCode != null &&
        savedCode.isNotEmpty &&
        _allowedLanguageCodes.contains(savedCode)) {
      initialLocale = Locale(savedCode);
    }

    if (!mounted) return;

    setState(() {
      _locale = initialLocale;
      _localeReady = true;
    });

    await _syncLocaleFromUserProfile();
  }

  Future<void> _syncLocaleFromUserProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final languageCode =
          await AuthService.instance.getCurrentLanguageCode(forceRefresh: true);

      if (!_allowedLanguageCodes.contains(languageCode)) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeStorageKey, languageCode);

      if (!mounted) return;

      setState(() {
        _locale = Locale(languageCode);
      });
    } catch (_) {}
  }

  Future<void> _setLocale(Locale locale) async {
    if (!_allowedLanguageCodes.contains(locale.languageCode)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeStorageKey, locale.languageCode);

    if (AuthService.instance.currentUser != null) {
      try {
        await AuthService.instance.updateCurrentLanguageCode(
          locale.languageCode,
        );
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeReady) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

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
      home: StreamBuilder<AuthState>(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) {
            return const AuthPage();
          }

          return HomePage(
            currentLocale: _locale,
            onLocaleChanged: _setLocale,
          );
        },
      ),
    );
  }
}
