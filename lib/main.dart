import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/home_page.dart';

/// Ponto de entrada da aplicação.
///
/// Esta função inicializa o Supabase e, em seguida, executa o aplicativo.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Substitua com suas credenciais do Supabase.
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  runApp(const AutonomoApp());
}

/// Widget raiz do aplicativo.
class AutonomoApp extends StatelessWidget {
  const AutonomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Autônomo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}
