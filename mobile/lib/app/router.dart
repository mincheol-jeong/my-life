import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_life/app/shell/app_shell.dart';
import 'package:my_life/core/localization/app_strings.dart';
import 'package:my_life/features/calendar_import/presentation/calendar_import_screen.dart';
import 'package:my_life/features/expense/presentation/expense_detail_screen.dart';
import 'package:my_life/features/expense/presentation/expense_form_screen.dart';
import 'package:my_life/features/finance/presentation/finance_screen.dart';
import 'package:my_life/features/home/presentation/home_screen.dart';
import 'package:my_life/features/photo/presentation/photo_detail_screen.dart';
import 'package:my_life/features/photo/presentation/photo_form_screen.dart';
import 'package:my_life/features/record/presentation/memo_detail_screen.dart';
import 'package:my_life/features/record/presentation/memo_form_screen.dart';
import 'package:my_life/features/record/presentation/record_entry_screen.dart';
import 'package:my_life/features/settings/presentation/me_screen.dart';
import 'package:my_life/features/timeline/presentation/timeline_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/timeline',
            builder: (context, state) => const TimelineScreen(),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceScreen(),
          ),
          GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
        ],
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) => const RecordEntryScreen(),
      ),
      GoRoute(
        path: '/calendar-import',
        builder: (context, state) => const CalendarImportScreen(),
      ),
      GoRoute(
        path: '/records/memo/new',
        builder: (context, state) => const MemoFormScreen(),
      ),
      GoRoute(
        path: '/records/expense/new',
        builder: (context, state) => const ExpenseFormScreen(),
      ),
      GoRoute(
        path: '/records/photo/new',
        builder: (context, state) => const PhotoFormScreen(),
      ),
      GoRoute(
        path: '/photos/:id',
        builder: (context, state) =>
            PhotoDetailScreen(recordId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                PhotoFormScreen(recordId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/expenses/:id',
        builder: (context, state) =>
            ExpenseDetailScreen(recordId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                ExpenseFormScreen(recordId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/records/:id',
        builder: (context, state) =>
            MemoDetailScreen(recordId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                MemoFormScreen(recordId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('MY LIFE')),
      body: Center(child: Text(context.strings.get('appError'))),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
