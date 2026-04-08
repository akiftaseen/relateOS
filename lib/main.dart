import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:relateos/config/theme.dart';
import 'package:relateos/features/auth/presentation/pages/splash_page.dart';
import 'package:relateos/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var supabaseReady = false;
  try {
    // Initialize Supabase when credentials are configured.
    await initializeSupabase();
    supabaseReady = true;
  } catch (_) {
    supabaseReady = false;
  }

  runApp(ProviderScope(child: RelateOSApp(supabaseReady: supabaseReady)));
}

class RelateOSApp extends ConsumerWidget {
  const RelateOSApp({super.key, required this.supabaseReady});

  final bool supabaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'RelateOS',
      theme: RelateOSTheme.lightTheme,
      darkTheme: RelateOSTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('zh', 'HK'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh', 'HK'),
        Locale('zh', 'CN'),
      ],
      home: SplashPage(supabaseReady: supabaseReady),
    );
  }
}
