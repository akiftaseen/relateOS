import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.supabaseReady});

  final bool supabaseReady;

  @override
  Widget build(BuildContext context) {
    final statusText = supabaseReady
        ? 'Backend connected. You can test app flows.'
        : 'Backend not configured yet. You can still test UI and local flows.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('RelateOS - Test Mode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(statusText),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.keyboard_alt_outlined),
                title: const Text('Keyboard Extension'),
                subtitle: const Text('Enable from iOS Settings to test suggestions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('How to test keyboard'),
                      content: const Text(
                        '1. Open iOS Settings > General > Keyboard > Keyboards\n'
                        '2. Add RelateOS keyboard\n'
                        '3. Enable Full Access\n'
                        '4. Open Notes or Messages and switch keyboard',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Health Score'),
                subtitle: const Text('Scoring engine is wired for local development'),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  supabaseReady ? Icons.check_circle : Icons.info_outline,
                  color: supabaseReady ? Colors.green : Colors.orange,
                ),
                title: const Text('Supabase Status'),
                subtitle: Text(supabaseReady ? 'Configured' : 'Missing credentials'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
