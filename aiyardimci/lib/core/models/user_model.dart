class UserModel {
  String? name;
  List<String> interests;
  List<String> facts;
  String relationshipLevel; // 'yeni' | 'tanışık' | 'arkadaş' | 'yakın'
  int totalInteractions;
  DateTime? firstMet;
  DateTime? lastSeen;

  UserModel({
    this.name,
    List<String>? interests,
    List<String>? facts,
    this.relationshipLevel = 'yeni',
    this.totalInteractions = 0,
    this.firstMet,
    this.lastSeen,
  })  : interests = interests ?? [],
        facts = facts ?? [];

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        name: json['name'] as String?,
        interests: (json['interests'] as List?)?.cast<String>() ?? [],
        facts: (json['facts'] as List?)?.cast<String>() ?? [],
        relationshipLevel: const {'yeni', 'tanışık', 'arkadaş', 'yakın'}
                .contains(json['relationshipLevel'])
            ? json['relationshipLevel'] as String
            : 'yeni',
        totalInteractions: json['totalInteractions'] as int? ?? 0,
        firstMet: json['firstMet'] != null
            ? DateTime.tryParse(json['firstMet'] as String)
            : null,
        lastSeen: json['lastSeen'] != null
            ? DateTime.tryParse(json['lastSeen'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'interests': interests,
        'facts': facts,
        'relationshipLevel': relationshipLevel,
        'totalInteractions': totalInteractions,
        'firstMet': firstMet?.toIso8601String(),
        'lastSeen': lastSeen?.toIso8601String(),
      };

  void updateRelationshipLevel() {
    if (totalInteractions < 5) {
      relationshipLevel = 'yeni';
    } else if (totalInteractions < 20) {
      relationshipLevel = 'tanışık';
    } else if (totalInteractions < 60) {
      relationshipLevel = 'arkadaş';
    } else {
      relationshipLevel = 'yakın';
    }
  }

  String toPromptSummary() {
    final parts = <String>[];
    if (name != null) parts.add('İsim: $name');
    if (interests.isNotEmpty) {
      parts.add('İlgi alanları: ${interests.take(10).join(', ')}');
    }
    if (facts.isNotEmpty) {
      parts.add('Bilinen gerçekler: ${facts.take(10).join('; ')}');
    }
    parts.add('İlişki: $relationshipLevel ($totalInteractions etkileşim)');
    return parts.join('\n');
  }
}
