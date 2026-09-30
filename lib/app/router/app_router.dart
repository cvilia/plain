/// go_router configuration. See 04-7, 06-D1.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/features/accounts/accounts_page.dart';
import 'package:plain/features/reports/reports_page.dart';
import 'package:plain/features/settings/settings_page.dart';
import 'package:plain/features/ledger/presentation/entry_detail_page.dart';
import 'package:plain/features/ledger/presentation/entry_input_page.dart';
import 'package:plain/features/ledger/presentation/flow_list_page.dart';
import 'package:plain/features/ledger/presentation/home_shell.dart';

class Routes {
  Routes._();
  static const String home = '/';
  static const String entry = '/entry';
  static const String entryEdit = '/entry/edit/:id';
  static const String entryDetail = '/entry/:id';
  static const String reports = '/reports';
  static const String accounts = '/accounts';
  static const String settings = '/settings';
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (context, state) => const FlowListPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.reports, builder: (context, state) => const ReportsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.accounts, builder: (context, state) => const AccountsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.settings, builder: (context, state) => const SettingsPage()),
          ]),
        ],
      ),
      GoRoute(path: Routes.entry, pageBuilder: (context, state) => MaterialPage(fullscreenDialog: true, child: const EntryInputPage())),
      GoRoute(
        path: Routes.entryEdit,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return MaterialPage(fullscreenDialog: true, child: EntryInputPage(editEntryId: id));
        },
      ),
      GoRoute(
        path: Routes.entryDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return EntryDetailPage(entryId: id);
        },
      ),
    ],
  );
}
