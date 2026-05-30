import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/instances_provider.dart';
import 'screens/deployments/deployments_screen.dart';
import 'screens/home_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/add_instance_screen.dart';
import 'screens/projects/projects_screen.dart';
import 'screens/resources/application_detail_screen.dart';
import 'screens/resources/create/create_application_screen.dart';
import 'screens/resources/create/create_database_screen.dart';
import 'screens/resources/create/create_service_screen.dart';
import 'screens/resources/database_detail_screen.dart';
import 'screens/resources/resources_screen.dart';
import 'screens/resources/service_detail_screen.dart';
import 'screens/servers/server_detail_screen.dart';
import 'screens/servers/servers_screen.dart';
import 'screens/settings/private_keys_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/team_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuild routing decisions whenever the set of accounts changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(instancesProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final instances = ref.read(instancesProvider);
      // Wait for the initial load before deciding.
      if (instances.isLoading || instances.hasError) return null;
      final hasInstances = instances.value?.instances.isNotEmpty ?? false;
      final atWelcome = state.matchedLocation == '/welcome';
      if (!hasInstances) return atWelcome ? null : '/welcome';
      if (atWelcome) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (_, _) => const AddInstanceScreen(isFirst: true),
      ),
      GoRoute(
        path: '/add-instance',
        builder: (_, _) => const AddInstanceScreen(),
      ),
      GoRoute(
        path: '/edit-instance/:id',
        builder: (_, state) =>
            AddInstanceScreen(instanceId: state.pathParameters['id']),
      ),
      // Detail + secondary routes live on the root navigator so they cover the
      // bottom nav.
      GoRoute(
        path: '/resources/create/app',
        builder: (_, _) => const CreateApplicationScreen(),
      ),
      GoRoute(
        path: '/resources/create/db',
        builder: (_, _) => const CreateDatabaseScreen(),
      ),
      GoRoute(
        path: '/resources/create/service',
        builder: (_, _) => const CreateServiceScreen(),
      ),
      GoRoute(
        path: '/resources/app/:uuid',
        builder: (_, state) =>
            ApplicationDetailScreen(uuid: state.pathParameters['uuid']!),
      ),
      GoRoute(
        path: '/resources/db/:uuid',
        builder: (_, state) =>
            DatabaseDetailScreen(uuid: state.pathParameters['uuid']!),
      ),
      GoRoute(
        path: '/resources/service/:uuid',
        builder: (_, state) =>
            ServiceDetailScreen(uuid: state.pathParameters['uuid']!),
      ),
      GoRoute(path: '/servers', builder: (_, _) => const ServersScreen()),
      GoRoute(
        path: '/servers/:uuid',
        builder: (_, state) =>
            ServerDetailScreen(uuid: state.pathParameters['uuid']!),
      ),
      GoRoute(path: '/projects', builder: (_, _) => const ProjectsScreen()),
      GoRoute(path: '/keys', builder: (_, _) => const PrivateKeysScreen()),
      GoRoute(path: '/team', builder: (_, _) => const TeamScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKeys[0],
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellKeys[1],
            routes: [
              GoRoute(
                path: '/resources',
                builder: (_, _) => const ResourcesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellKeys[2],
            routes: [
              GoRoute(
                path: '/deployments',
                builder: (_, _) => const DeploymentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellKeys[3],
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
