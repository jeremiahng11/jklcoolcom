import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/team.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/async_value_view.dart';
import '../resources/detail_widgets.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(currentTeamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: AsyncValueView<Team?>(
        value: team,
        onRetry: () => ref.invalidate(currentTeamProvider),
        data: (t) {
          if (t == null) {
            return const Center(child: Text('No team information.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(currentTeamProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DetailSection(
                  title: 'Team',
                  children: [
                    InfoRow('Name', t.name),
                    if (t.description.isNotEmpty)
                      InfoRow('Description', t.description),
                    InfoRow('Personal team', t.personalTeam ? 'Yes' : 'No'),
                    InfoRow('Members', '${t.members.length}'),
                  ],
                ),
                if (t.members.isNotEmpty)
                  DetailSection(
                    title: 'Members',
                    children: t.members
                        .map(
                          (m) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(
                                m.name.isNotEmpty
                                    ? m.name[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(m.name),
                            subtitle: Text(m.email),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
