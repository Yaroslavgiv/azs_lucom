import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/web/web_shell.dart';

class AzsWebApp extends ConsumerWidget {
  const AzsWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'АЗС — панель руководителя',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: auth.when(
        data: (user) => user == null ? const LoginPage() : const WebShell(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      ),
    );
  }
}
