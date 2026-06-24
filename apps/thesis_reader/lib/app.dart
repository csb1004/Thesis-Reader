import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thesis_reader/features/library/presentation/import_status_screen.dart';
import 'package:thesis_reader/features/library/presentation/library_screen.dart';
import 'package:thesis_reader/features/reader/presentation/reader_screen.dart';

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LibraryScreen()),
    GoRoute(
      path: '/import/:documentId',
      builder: (context, state) => ImportStatusScreen(
        documentId: state.pathParameters['documentId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/reader/:documentId',
      builder: (context, state) =>
          ReaderScreen(documentId: state.pathParameters['documentId'] ?? ''),
    ),
  ],
);

class ThesisReaderApp extends StatelessWidget {
  const ThesisReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Thesis Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      routerConfig: _router,
    );
  }
}
