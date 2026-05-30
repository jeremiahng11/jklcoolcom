import 'json_utils.dart';

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.description,
    required this.personalTeam,
    required this.members,
  });

  final int id;
  final String name;
  final String description;
  final bool personalTeam;
  final List<TeamMember> members;

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: asIntOr(json['id']),
      name: asStringOr(json['name'], 'Team'),
      description: asStringOr(json['description']),
      personalTeam: asBool(json['personal_team']),
      members: asMapList(json['members']).map(TeamMember.fromJson).toList(),
    );
  }
}

class TeamMember {
  const TeamMember({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: asIntOr(json['id']),
      name: asStringOr(json['name']),
      email: asStringOr(json['email']),
    );
  }
}
