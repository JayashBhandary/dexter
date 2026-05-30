import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'domain/connection_record.dart';
import 'ui/connection_form/connection_form_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/connection/new',
        builder: (context, state) => const ConnectionFormPage(),
      ),
      GoRoute(
        path: '/connection/edit',
        builder: (context, state) => ConnectionFormPage(
          editing: state.extra as ConnectionRecord?,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
