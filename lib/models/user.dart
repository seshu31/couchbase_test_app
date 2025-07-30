import 'package:cbl/cbl.dart';

class User {
  const User({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String email;
  final DateTime createdAt;

  factory User.fromDict(DictionaryInterface dict) {
    return User(
      id: dict is Document ? dict.id : dict.value('id')!,
      email: dict.value('email')!,
      createdAt: dict.value('createdAt')!,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': 'user',
      'email': email,
      'createdAt': createdAt,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;

  @override
  String toString() => 'User(id: $id, email: $email)';
} 