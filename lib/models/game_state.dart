enum Role {
  liberal,
  fascist,
  secretHitler,
}

extension RoleExtension on Role {
  String get name {
    switch (this) {
      case Role.liberal:
        return 'Liberal';
      case Role.fascist:
        return 'Fascist';
      case Role.secretHitler:
        return 'Secret Hitler';
    }
  }

  // Fascist party includes both Fascists and Secret Hitler
  String get partyName {
    switch (this) {
      case Role.liberal:
        return 'Liberal';
      case Role.fascist:
      case Role.secretHitler:
        return 'Fascist';
    }
  }
}

enum PolicyType {
  liberal,
  fascist,
}

enum GamePhase {
  setup,
  roleReveal,
  electionNomination,
  electionVoting,
  legislativePresident,
  legislativeChancellor,
  executiveAction,
  gameOver,
}

enum ExecutivePower {
  none,
  investigateLoyalty, // Examine a player's party membership card
  callSpecialElection, // Nominate the next President directly
  policyPeek, // View the top 3 cards of the policy deck
  execution, // Eliminate a player from the game
}

class Player {
  final int id;
  final String name;
  Role? role;
  bool isAlive;
  bool isInvestigated;
  final String avatar;

  Player({
    required this.id,
    required this.name,
    this.role,
    this.isAlive = true,
    this.isInvestigated = false,
    this.avatar = 'avatar_1',
  });

  Player copyWith({
    int? id,
    String? name,
    Role? role,
    bool? isAlive,
    bool? isInvestigated,
    String? avatar,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
      isInvestigated: isInvestigated ?? this.isInvestigated,
      avatar: avatar ?? this.avatar,
    );
  }
}
