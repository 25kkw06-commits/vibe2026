import 'dart:convert';

class Tamagotchi {
  final String name;
  final DateTime bornAt;
  final int hunger;        // 0=포만, 100=굶주림
  final int cleanliness;   // 0=더러움, 100=깨끗
  final int happiness;     // 0=우울, 100=행복
  final int sicknessCount; // 누적 병든 횟수 (3이면 사망)
  final bool isSick;       // 현재 병중 여부
  final bool isAlive;
  final int medicineCount; // 치료제 개수
  final DateTime lastDecayAt;
  final String lastEvaluatedDate; // YYYY-MM-DD, 마지막 평가일
  final List<String> exceededTodayPackages;
  final DateTime? lastFedAt;
  final DateTime? lastBathedAt;
  final DateTime? lastPlayedAt;

  const Tamagotchi({
    required this.name,
    required this.bornAt,
    required this.hunger,
    required this.cleanliness,
    required this.happiness,
    required this.sicknessCount,
    required this.isSick,
    required this.isAlive,
    required this.medicineCount,
    required this.lastDecayAt,
    required this.lastEvaluatedDate,
    required this.exceededTodayPackages,
    this.lastFedAt,
    this.lastBathedAt,
    this.lastPlayedAt,
  });

  factory Tamagotchi.newborn({String name = '미미'}) {
    final now = DateTime.now();
    return Tamagotchi(
      name: name,
      bornAt: now,
      hunger: 30,
      cleanliness: 80,
      happiness: 70,
      sicknessCount: 0,
      isSick: false,
      isAlive: true,
      medicineCount: 0,
      lastDecayAt: now,
      lastEvaluatedDate: _today(),
      exceededTodayPackages: const [],
    );
  }

  int get ageDays => DateTime.now().difference(bornAt).inDays;

  int get overallMood {
    final h = 100 - hunger;
    return ((h + cleanliness + happiness) / 3).round();
  }

  /// 캐릭터 이모지 — 다마고치의 시각적 핵심이라 유지.
  String get displayEmoji {
    if (!isAlive) return '💤';
    if (isSick) return '🤒';
    if (hunger > 85) return '😩';
    if (cleanliness < 20) return '🫥';
    if (happiness < 20) return '😢';
    if (ageDays < 1) return '🥚';
    if (ageDays < 3) return '🐣';
    if (ageDays < 7) return '🐥';
    if (ageDays < 21) return '🐤';
    return '🐔';
  }

  String get stageLabel {
    if (!isAlive) return '하늘나라';
    if (ageDays < 1) return '알';
    if (ageDays < 3) return '신생아';
    if (ageDays < 7) return '아기';
    if (ageDays < 21) return '청소년';
    return '어른';
  }

  Tamagotchi copyWith({
    String? name,
    DateTime? bornAt,
    int? hunger,
    int? cleanliness,
    int? happiness,
    int? sicknessCount,
    bool? isSick,
    bool? isAlive,
    int? medicineCount,
    DateTime? lastDecayAt,
    String? lastEvaluatedDate,
    List<String>? exceededTodayPackages,
    DateTime? lastFedAt,
    DateTime? lastBathedAt,
    DateTime? lastPlayedAt,
  }) {
    return Tamagotchi(
      name: name ?? this.name,
      bornAt: bornAt ?? this.bornAt,
      hunger: (hunger ?? this.hunger).clamp(0, 100),
      cleanliness: (cleanliness ?? this.cleanliness).clamp(0, 100),
      happiness: (happiness ?? this.happiness).clamp(0, 100),
      sicknessCount: (sicknessCount ?? this.sicknessCount).clamp(0, 999),
      isSick: isSick ?? this.isSick,
      isAlive: isAlive ?? this.isAlive,
      medicineCount: (medicineCount ?? this.medicineCount).clamp(0, 999),
      lastDecayAt: lastDecayAt ?? this.lastDecayAt,
      lastEvaluatedDate: lastEvaluatedDate ?? this.lastEvaluatedDate,
      exceededTodayPackages:
          exceededTodayPackages ?? this.exceededTodayPackages,
      lastFedAt: lastFedAt ?? this.lastFedAt,
      lastBathedAt: lastBathedAt ?? this.lastBathedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'bornAt': bornAt.toIso8601String(),
        'hunger': hunger,
        'cleanliness': cleanliness,
        'happiness': happiness,
        'sicknessCount': sicknessCount,
        'isSick': isSick,
        'isAlive': isAlive,
        'medicineCount': medicineCount,
        'lastDecayAt': lastDecayAt.toIso8601String(),
        'lastEvaluatedDate': lastEvaluatedDate,
        'exceededTodayPackages': exceededTodayPackages,
        'lastFedAt': lastFedAt?.toIso8601String(),
        'lastBathedAt': lastBathedAt?.toIso8601String(),
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      };

  factory Tamagotchi.fromMap(Map<String, dynamic> m) => Tamagotchi(
        name: m['name'] as String,
        bornAt: DateTime.parse(m['bornAt'] as String),
        hunger: m['hunger'] as int,
        cleanliness: m['cleanliness'] as int,
        happiness: m['happiness'] as int,
        sicknessCount: m['sicknessCount'] as int,
        isSick: m['isSick'] as bool,
        isAlive: m['isAlive'] as bool,
        medicineCount: m['medicineCount'] as int,
        lastDecayAt: DateTime.parse(m['lastDecayAt'] as String),
        lastEvaluatedDate: m['lastEvaluatedDate'] as String,
        exceededTodayPackages:
            (m['exceededTodayPackages'] as List).cast<String>(),
        lastFedAt: m['lastFedAt'] != null
            ? DateTime.parse(m['lastFedAt'] as String)
            : null,
        lastBathedAt: m['lastBathedAt'] != null
            ? DateTime.parse(m['lastBathedAt'] as String)
            : null,
        lastPlayedAt: m['lastPlayedAt'] != null
            ? DateTime.parse(m['lastPlayedAt'] as String)
            : null,
      );

  String toJson() => json.encode(toMap());

  factory Tamagotchi.fromJson(String s) =>
      Tamagotchi.fromMap(json.decode(s) as Map<String, dynamic>);

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static String todayStamp() => _today();
}
