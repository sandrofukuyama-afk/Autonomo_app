import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'entries_page.dart';
import 'expenses_page.dart';
import 'reports_page.dart';

/// Home page of the application that holds a bottom navigation bar and
/// provides a language selector. When a language is chosen from the
/// drop‑down menu in the app bar, the provided [onLocaleChanged]
/// callback is invoked to update the app's locale.
class HomePage extends StatefulWidget {
  /// Creates a new [HomePage]. The [onLocaleChanged] callback must
  /// not be null so that the widget can propagate locale changes to
  /// the enclosing [MaterialApp].
  const HomePage({super.key, required this.onLocaleChanged});

  /// Callback invoked when the user selects a new language. The
  /// [Locale] passed to this function will be used by the app.
  final void Function(Locale) onLocaleChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  /// Returns the appropriate app bar title based on the current index.
  String _getAppBarTitle(AppLocalizations localizations) {
    switch (_currentIndex) {
      case 0:
        return localizations.translate('nav_home');
      case 1:
        return localizations.translate('nav_entries');
      case 2:
        return localizations.translate('nav_expenses');
      case 3:
        return localizations.translate('nav_reports');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // The pages corresponding to each tab. The first page is a simple
    // dashboard placeholder that can be replaced with a more complete
    // implementation when available.
    final pages = <Widget>[
      const _DashboardPage(),
      const EntriesPage(),
      const ExpensesPage(),
      const ReportsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(localizations)),
        actions: [
          PopupMenuButton<String>(
            tooltip: localizations.translate('select_language'),
            icon: const Icon(Icons.language),
            onSelected: (String languageCode) {
              // Update the locale via the callback passed from MyApp.
              widget.onLocaleChanged(Locale(languageCode));
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'pt',
                child: Text(localizations.translate('lang_pt')),
              ),
              PopupMenuItem<String>(
                value: 'en',
                child: Text(localizations.translate('lang_en')),
              ),
              PopupMenuItem<String>(
                value: 'ja',
                child: Text(localizations.translate('lang_ja')),
              ),
              PopupMenuItem<String>(
                value: 'es',
                child: Text(localizations.translate('lang_es')),
              ),
            ],
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.dashboard),
            label: localizations.translate('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.trending_up),
            label: localizations.translate('nav_entries'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.trending_down),
            label: localizations.translate('nav_expenses'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart),
            label: localizations.translate('nav_reports'),
          ),
        ],
      ),
    );
  }
}

/// A simple placeholder for the dashboard page. Replace this widget
/// with a more complete dashboard implementation as your app evolves.
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Text(
        localizations.translate('nav_home'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
