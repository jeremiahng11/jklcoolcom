import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'navigation.dart';
import 'providers/instances_provider.dart';
import 'screens/deployments/deployments_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/home_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/add_instance_screen.dart';
import 'screens/onboarding/connect_guide_screen.dart';
import 'screens/projects/project_detail_screen.dart';
import 'screens/projects/projects_screen.dart';
import 'screens/resources/application_detail_screen.dart';
import 'screens/resources/create/create_application_screen.dart';
import 'screens/resources/create/create_database_screen.dart';
import 'screens/resources/create/create_service_screen.dart';
import 'screens/resources/database_detail_screen.dart';
import 'screens/resources/resources_screen.dart';
import 'screens/resources/service_detail_screen.dart';
import 'screens/servers/add_server_screen.dart';
import 'screens/servers/connect_cloud_guide_screen.dart';
import 'screens/servers/server_detail_screen.dart';
import 'screens/servers/servers_screen.dart';
import 'screens/settings/cloud_tokens_screen.dart';
import 'screens/settings/cloudflare_tunnel_screen.dart';
import 'screens/settings/coolify_notifications_guide_screen.dart';
import 'screens/settings/metrics_setup_screen.dart';
import 'screens/settings/push_server_guide_screen.dart';
import 'screens/servers/hetzner_provision_screen.dart';
import 'screens/settings/private_keys_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/team_screen.dart';

final _shellKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

final routerProvider = Provider<GoRouter>((ref) {
  // Only re-evaluate routing when accounts go empty <-> non-empty (the only
  // thing redirect cares about). Refreshing on every label/accent/token edit
  // caused the current screen to rebuild — a flicker on Save.
  final refresh = ValueNotifier<int>(0);
  var hadInstances =
      ref.read(instancesProvider).value?.instances.isNotEmpty ?? false;
  ref.listen(instancesProvider, (_, next) {
    final now = next.value?.instances.isNotEmpty ?? false;
    if (now != hadInstances) {
      hadInstances = now;
      refresh.value++;
    }
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
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
        path: '/connect-guide',
        builder: (_, _) => const ConnectGuideScreen(),
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
      GoRoute(path: '/servers/add', builder: (_, _) => const AddServerScreen()),
      GoRoute(
        path: '/servers/hetzner',
        builder: (_, _) => const HetznerProvisionScreen(),
      ),
      GoRoute(
        path: '/servers/connect-cloud',
        builder: (_, _) => const ConnectCloudGuideScreen(),
      ),
      GoRoute(
        path: '/servers/:uuid',
        builder: (_, state) =>
            ServerDetailScreen(uuid: state.pathParameters['uuid']!),
      ),
      GoRoute(path: '/projects', builder: (_, _) => const ProjectsScreen()),
      GoRoute(
        path: '/projects/:uuid',
        builder: (_, state) =>
            ProjectDetailScreen(uuid: state.pathParameters['uuid']!),
      ),
      GoRoute(path: '/keys', builder: (_, _) => const PrivateKeysScreen()),
      GoRoute(
        path: '/cloud-tokens',
        builder: (_, _) => const CloudTokensScreen(),
      ),
      GoRoute(path: '/team', builder: (_, _) => const TeamScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/coolify-notifications-guide',
        builder: (_, _) => const CoolifyNotificationsGuideScreen(),
      ),
      GoRoute(
        path: '/push-server-guide',
        builder: (_, _) => const PushServerGuideScreen(),
      ),
      GoRoute(
        path: '/metrics-setup',
        builder: (_, _) => const MetricsSetupScreen(),
      ),
      GoRoute(
        path: '/cloudflare-tunnel',
        builder: (_, _) => const CloudflareTunnelScreen(),
      ),
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
