/// A player: a stable id and a display name. The profile of the signed-in
/// account is flagged [linkedToAccount]; it is managed by sign-in/out and
/// cannot be deleted by hand.
class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.name,
    this.linkedToAccount = false,
  });

  final String id;
  final String name;
  final bool linkedToAccount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (linkedToAccount) 'linkedToAccount': true,
  };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    linkedToAccount: json['linkedToAccount'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerProfile &&
      other.id == id &&
      other.name == name &&
      other.linkedToAccount == linkedToAccount;

  @override
  int get hashCode => Object.hash(id, name, linkedToAccount);
}
