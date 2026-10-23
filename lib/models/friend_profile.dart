/// Another account as friends see it: uid, display name and friend code.
class FriendProfile {
  const FriendProfile({
    required this.uid,
    required this.name,
    required this.code,
  });

  final String uid;
  final String name;
  final String code;

  Map<String, dynamic> toJson() => {'uid': uid, 'name': name, 'code': code};

  factory FriendProfile.fromJson(Map<String, dynamic> json) => FriendProfile(
    uid: json['uid'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
  );

  @override
  bool operator ==(Object other) =>
      other is FriendProfile &&
      other.uid == uid &&
      other.name == name &&
      other.code == code;

  @override
  int get hashCode => Object.hash(uid, name, code);
}
