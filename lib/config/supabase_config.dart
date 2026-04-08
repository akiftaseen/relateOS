import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'YOUR_SUPABASE_URL'; // TODO: Replace with actual URL
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY'; // TODO: Replace with actual key

Future<void> initializeSupabase() async {
  if (supabaseUrl.startsWith('YOUR_') || supabaseAnonKey.startsWith('YOUR_')) {
    throw StateError('Supabase credentials are not configured yet.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}

final supabaseClient = Supabase.instance.client;
