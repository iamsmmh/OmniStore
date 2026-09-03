import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/discover/presentation/pages/discover_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/updates/presentation/pages/updates_page.dart';
import '../../features/downloads/presentation/pages/downloads_page.dart';
import '../../features/repositories/presentation/pages/repositories_page.dart';
import '../../features/repositories/presentation/pages/source_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/health/presentation/pages/health_page.dart';
import '../../features/app_details/presentation/pages/app_details_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(path: 'discover', builder: (context, state) => const DiscoverPage()),
          GoRoute(path: 'search', builder: (context, state) => const SearchPage()),
          GoRoute(path: 'updates', builder: (context, state) => const UpdatesPage()),
          GoRoute(path: 'downloads', builder: (context, state) => const DownloadsPage()),
          GoRoute(path: 'repositories', builder: (context, state) => const RepositoriesPage()),
          GoRoute(path: 'health', builder: (context, state) => const HealthPage()),
          GoRoute(path: 'settings', builder: (context, state) => const SettingsPage()),
          GoRoute(
            path: 'app/:id',
            builder: (context, state) {
              final appId = state.pathParameters['id']!;
              return AppDetailsPage(appId: appId);
            },
          ),
          GoRoute(
            path: 'source/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return SourceDetailsPage(repositoryId: id);
            },
          ),
        ],
      ),
    ],
  );
});
