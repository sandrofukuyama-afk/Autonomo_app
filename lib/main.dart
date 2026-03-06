import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dzazwpgjncowkudkdhca.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6YXp3cGdqbmNvd2t1ZGtkaGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MDIyODAsImV4cCI6MjA4ODM3ODI4MH0.mQBxjBlgPQpxb5-QyFNhgitM_WOnWlkEzFStYZPr5Pk',
  );

  runApp(MyApp());
}
