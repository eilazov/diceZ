/// A locally-created player: just a stable id and a display name.
class PlayerProfile {
  const PlayerProfile({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is PlayerProfile && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
