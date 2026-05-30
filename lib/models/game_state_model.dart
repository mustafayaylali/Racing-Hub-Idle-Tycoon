import 'package:flutter/foundation.dart';

@immutable
class EquipmentItem {
  final String id;
  final String name;
  final String type; // 'horseshoe', 'whip', 'saddle'
  final String rarity; // 'common', 'rare', 'epic', 'legendary'
  final double winChanceBonus;

  const EquipmentItem({
    required this.id,
    required this.name,
    required this.type,
    required this.rarity,
    required this.winChanceBonus,
  });

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    return EquipmentItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      rarity: json['rarity'] as String,
      winChanceBonus: (json['winChanceBonus'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'rarity': rarity,
      'winChanceBonus': winChanceBonus,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          rarity == other.rarity &&
          winChanceBonus == other.winChanceBonus;

  @override
  int get hashCode => Object.hash(id, name, type, rarity, winChanceBonus);

  @override
  String toString() {
    return 'EquipmentItem(id: $id, name: $name, type: $type, rarity: $rarity, winChanceBonus: $winChanceBonus)';
  }
}

@immutable
class HorseAsset {
  final String id;
  final String name;
  final int associatedLeagueTier;
  final int currentStars;
  final int duplicateCardCount;
  final Map<String, int> stats;

  const HorseAsset({
    required this.id,
    required this.name,
    required this.associatedLeagueTier,
    required this.currentStars,
    required this.duplicateCardCount,
    required this.stats,
  });

  factory HorseAsset.fromJson(Map<String, dynamic> json) {
    return HorseAsset(
      id: json['id'] as String,
      name: json['name'] as String,
      associatedLeagueTier: (json['associatedLeagueTier'] as num).toInt(),
      currentStars: (json['currentStars'] as num).toInt(),
      duplicateCardCount: (json['duplicateCardCount'] as num).toInt(),
      stats: Map<String, int>.from(json['stats'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'associatedLeagueTier': associatedLeagueTier,
      'currentStars': currentStars,
      'duplicateCardCount': duplicateCardCount,
      'stats': stats,
    };
  }

  HorseAsset copyWith({
    String? id,
    String? name,
    int? associatedLeagueTier,
    int? currentStars,
    int? duplicateCardCount,
    Map<String, int>? stats,
  }) {
    return HorseAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      associatedLeagueTier: associatedLeagueTier ?? this.associatedLeagueTier,
      currentStars: currentStars ?? this.currentStars,
      duplicateCardCount: duplicateCardCount ?? this.duplicateCardCount,
      stats: stats ?? this.stats,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HorseAsset &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          associatedLeagueTier == other.associatedLeagueTier &&
          currentStars == other.currentStars &&
          duplicateCardCount == other.duplicateCardCount &&
          mapEquals(stats, other.stats);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        associatedLeagueTier,
        currentStars,
        duplicateCardCount,
        Object.hash(Object.hashAll(stats.keys), Object.hashAll(stats.values)),
      );

  @override
  String toString() {
    return 'HorseAsset(id: $id, name: $name, associatedLeagueTier: $associatedLeagueTier, currentStars: $currentStars, duplicateCardCount: $duplicateCardCount, stats: $stats)';
  }
}

@immutable
class JockeyAsset {
  final String id;
  final String name;
  final int associatedLeagueTier;
  final int currentStars;
  final int duplicateCardCount;
  final Map<String, int> skills;

  const JockeyAsset({
    required this.id,
    required this.name,
    required this.associatedLeagueTier,
    required this.currentStars,
    required this.duplicateCardCount,
    required this.skills,
  });

  factory JockeyAsset.fromJson(Map<String, dynamic> json) {
    return JockeyAsset(
      id: json['id'] as String,
      name: json['name'] as String,
      associatedLeagueTier: (json['associatedLeagueTier'] as num).toInt(),
      currentStars: (json['currentStars'] as num).toInt(),
      duplicateCardCount: (json['duplicateCardCount'] as num).toInt(),
      skills: Map<String, int>.from(json['skills'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'associatedLeagueTier': associatedLeagueTier,
      'currentStars': currentStars,
      'duplicateCardCount': duplicateCardCount,
      'skills': skills,
    };
  }

  JockeyAsset copyWith({
    String? id,
    String? name,
    int? associatedLeagueTier,
    int? currentStars,
    int? duplicateCardCount,
    Map<String, int>? skills,
  }) {
    return JockeyAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      associatedLeagueTier: associatedLeagueTier ?? this.associatedLeagueTier,
      currentStars: currentStars ?? this.currentStars,
      duplicateCardCount: duplicateCardCount ?? this.duplicateCardCount,
      skills: skills ?? this.skills,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JockeyAsset &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          associatedLeagueTier == other.associatedLeagueTier &&
          currentStars == other.currentStars &&
          duplicateCardCount == other.duplicateCardCount &&
          mapEquals(skills, other.skills);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        associatedLeagueTier,
        currentStars,
        duplicateCardCount,
        Object.hash(Object.hashAll(skills.keys), Object.hashAll(skills.values)),
      );

  @override
  String toString() {
    return 'JockeyAsset(id: $id, name: $name, associatedLeagueTier: $associatedLeagueTier, currentStars: $currentStars, duplicateCardCount: $duplicateCardCount, skills: $skills)';
  }
}

@immutable
class GameStateModel {
  final double gold;
  final int diamonds;
  final String currentDerbyLeague;
  final int leagueTier;
  final double leaguePoints;
  final double winChance;
  final double goldPerSecond;
  final List<double> horsePositions;
  final int raceTimeLeft;
  final int raceDurationSeconds;
  final int currentTabIndex;
  final List<HorseAsset> horses;
  final List<JockeyAsset> jockeys;
  final Map<String, int> buildings;
  final List<EquipmentItem> inventory;
  final Map<String, String> equippedEquipment;
  final DateTime lastSaved;

  // New Fields
  final int unlockedLeagueTier;
  final List<int> recentPlacements;
  final int boostTimeLeft;
  final int currentSeasonRace;
  final double seasonPoints;
  final List<double> rivalSeasonPoints;
  final List<String> rivalJockeyNames;
  final int currentClassIndex;
  final bool sponsorActive;
  final double sponsorPosition;
  final String raceState; // 'racing' or 'results'
  final int resultsCountdown;
  final int lastRacePlacement;
  final double lastRaceGoldEarned;
  final double lastRacePointsEarned;
  final bool hasChangedHorseName;
  final int playerGateNumber;
  final List<String> currentRaceRivalNames;
  final double pendingOfflineGold;
  final List<int> raceRanks;
  final int season;
  final int lastSeasonRank;
  final int offlineDurationSeconds;
  final List<int> seasonHistory;
  final List<String> seasonClassHistory;

  const GameStateModel({
    required this.gold,
    required this.diamonds,
    required this.currentDerbyLeague,
    required this.leagueTier,
    required this.leaguePoints,
    required this.winChance,
    required this.goldPerSecond,
    required this.horsePositions,
    required this.raceTimeLeft,
    required this.raceDurationSeconds,
    required this.currentTabIndex,
    required this.horses,
    required this.jockeys,
    required this.buildings,
    required this.inventory,
    required this.equippedEquipment,
    required this.lastSaved,
    required this.unlockedLeagueTier,
    required this.recentPlacements,
    required this.boostTimeLeft,
    required this.currentSeasonRace,
    required this.seasonPoints,
    required this.rivalSeasonPoints,
    required this.rivalJockeyNames,
    required this.currentClassIndex,
    required this.sponsorActive,
    required this.sponsorPosition,
    required this.raceState,
    required this.resultsCountdown,
    required this.lastRacePlacement,
    required this.lastRaceGoldEarned,
    required this.lastRacePointsEarned,
    required this.hasChangedHorseName,
    required this.playerGateNumber,
    required this.currentRaceRivalNames,
    required this.pendingOfflineGold,
    required this.raceRanks,
    required this.season,
    required this.lastSeasonRank,
    required this.offlineDurationSeconds,
    required this.seasonHistory,
    required this.seasonClassHistory,
  });

  static List<HorseAsset> defaultHorses() {
    return const [
      HorseAsset(
        id: 'h_0',
        name: 'Pony Express',
        associatedLeagueTier: 0,
        currentStars: 1,
        duplicateCardCount: 0,
        stats: {
          'speed': 0,
          'acceleration': 0,
          'stamina': 0,
          'focus': 0,
          'temper': 0,
          'cornering': 0,
        },
      ),
      HorseAsset(
        id: 'h_1',
        name: 'Cobalt Charger',
        associatedLeagueTier: 1,
        currentStars: 1,
        duplicateCardCount: 0,
        stats: {
          'speed': 0,
          'acceleration': 0,
          'stamina': 0,
          'focus': 0,
          'temper': 0,
          'cornering': 0,
        },
      ),
      HorseAsset(
        id: 'h_2',
        name: 'Emerald Wind',
        associatedLeagueTier: 2,
        currentStars: 1,
        duplicateCardCount: 0,
        stats: {
          'speed': 0,
          'acceleration': 0,
          'stamina': 0,
          'focus': 0,
          'temper': 0,
          'cornering': 0,
        },
      ),
      HorseAsset(
        id: 'h_3',
        name: 'Crimson Thunder',
        associatedLeagueTier: 3,
        currentStars: 1,
        duplicateCardCount: 0,
        stats: {
          'speed': 0,
          'acceleration': 0,
          'stamina': 0,
          'focus': 0,
          'temper': 0,
          'cornering': 0,
        },
      ),
      HorseAsset(
        id: 'h_4',
        name: 'Golden Eclipse',
        associatedLeagueTier: 4,
        currentStars: 1,
        duplicateCardCount: 0,
        stats: {
          'speed': 0,
          'acceleration': 0,
          'stamina': 0,
          'focus': 0,
          'temper': 0,
          'cornering': 0,
        },
      ),
      HorseAsset(
        id: 'h_5',
        name: 'Pegasus Prime',
        associatedLeagueTier: 5,
        currentStars: 1,
        duplicateCardCount: 0,
        stats: {
          'speed': 0,
          'acceleration': 0,
          'stamina': 0,
          'focus': 0,
          'temper': 0,
          'cornering': 0,
        },
      ),
    ];
  }

  static List<JockeyAsset> defaultJockeys() {
    return const [
      JockeyAsset(
        id: 'j_0',
        name: 'Billy Kid',
        associatedLeagueTier: 0,
        currentStars: 1,
        duplicateCardCount: 0,
        skills: {
          'tactics': 0,
          'pacing': 0,
          'reflexes': 0,
        },
      ),
      JockeyAsset(
        id: 'j_1',
        name: 'Jane Gallop',
        associatedLeagueTier: 1,
        currentStars: 1,
        duplicateCardCount: 0,
        skills: {
          'tactics': 0,
          'pacing': 0,
          'reflexes': 0,
        },
      ),
      JockeyAsset(
        id: 'j_2',
        name: 'Jack Pacer',
        associatedLeagueTier: 2,
        currentStars: 1,
        duplicateCardCount: 0,
        skills: {
          'tactics': 0,
          'pacing': 0,
          'reflexes': 0,
        },
      ),
      JockeyAsset(
        id: 'j_3',
        name: 'Ace Whip',
        associatedLeagueTier: 3,
        currentStars: 1,
        duplicateCardCount: 0,
        skills: {
          'tactics': 0,
          'pacing': 0,
          'reflexes': 0,
        },
      ),
      JockeyAsset(
        id: 'j_4',
        name: 'Duke Jockey',
        associatedLeagueTier: 4,
        currentStars: 1,
        duplicateCardCount: 0,
        skills: {
          'tactics': 0,
          'pacing': 0,
          'reflexes': 0,
        },
      ),
      JockeyAsset(
        id: 'j_5',
        name: 'Star Rider',
        associatedLeagueTier: 5,
        currentStars: 1,
        duplicateCardCount: 0,
        skills: {
          'tactics': 0,
          'pacing': 0,
          'reflexes': 0,
        },
      ),
    ];
  }

  factory GameStateModel.initial() {
    return GameStateModel(
      gold: 500.0,
      diamonds: 10,
      currentDerbyLeague: 'Village League',
      leagueTier: 0,
      leaguePoints: 0.0,
      winChance: 0.20,
      goldPerSecond: 0.0,
      horsePositions: const [0.0, 0.0, 0.0, 0.0, 0.0],
      raceTimeLeft: 450,
      raceDurationSeconds: 45,
      currentTabIndex: 0,
      horses: defaultHorses(),
      jockeys: defaultJockeys(),
      buildings: const {
        'training_track': 0,
        'medical_center': 0,
        'feed_storage': 0,
        'research_lab': 0,
        'luxury_stable': 0,
      },
      inventory: const [],
      equippedEquipment: const {},
      lastSaved: DateTime.now(),
      unlockedLeagueTier: 0,
      recentPlacements: const [],
      boostTimeLeft: 0,
      currentSeasonRace: 1,
      seasonPoints: 0.0,
      rivalSeasonPoints: const [0.0, 0.0, 0.0, 0.0],
      rivalJockeyNames: const ['Galopping Greg', 'Speedy Sarah', 'Blitzing Bob', 'Thundering Ted'],
      currentClassIndex: 0,
      sponsorActive: false,
      sponsorPosition: 1.0,
      raceState: 'racing',
      resultsCountdown: 0,
      lastRacePlacement: 1,
      lastRaceGoldEarned: 0.0,
      lastRacePointsEarned: 0.0,
      hasChangedHorseName: false,
      playerGateNumber: 0,
      currentRaceRivalNames: const ['Thunderbolt', 'Silver Arrow', 'Desert Storm', 'Night Fury'],
      pendingOfflineGold: 0.0,
      raceRanks: const [1, 2, 3, 4, 5],
      season: 1,
      lastSeasonRank: 0,
      offlineDurationSeconds: 0,
      seasonHistory: const [],
      seasonClassHistory: const [],
    );
  }

  GameStateModel copyWith({
    double? gold,
    int? diamonds,
    String? currentDerbyLeague,
    int? leagueTier,
    double? leaguePoints,
    double? winChance,
    double? goldPerSecond,
    List<double>? horsePositions,
    int? raceTimeLeft,
    int? raceDurationSeconds,
    int? currentTabIndex,
    List<HorseAsset>? horses,
    List<JockeyAsset>? jockeys,
    Map<String, int>? buildings,
    List<EquipmentItem>? inventory,
    Map<String, String>? equippedEquipment,
    DateTime? lastSaved,
    int? unlockedLeagueTier,
    List<int>? recentPlacements,
    int? boostTimeLeft,
    int? currentSeasonRace,
    double? seasonPoints,
    List<double>? rivalSeasonPoints,
    List<String>? rivalJockeyNames,
    int? currentClassIndex,
    bool? sponsorActive,
    double? sponsorPosition,
    String? raceState,
    int? resultsCountdown,
    int? lastRacePlacement,
    double? lastRaceGoldEarned,
    double? lastRacePointsEarned,
    bool? hasChangedHorseName,
    int? playerGateNumber,
    List<String>? currentRaceRivalNames,
    double? pendingOfflineGold,
    List<int>? raceRanks,
    int? season,
    int? lastSeasonRank,
    int? offlineDurationSeconds,
    List<int>? seasonHistory,
    List<String>? seasonClassHistory,
  }) {
    return GameStateModel(
      gold: gold ?? this.gold,
      diamonds: diamonds ?? this.diamonds,
      currentDerbyLeague: currentDerbyLeague ?? this.currentDerbyLeague,
      leagueTier: leagueTier ?? this.leagueTier,
      leaguePoints: leaguePoints ?? this.leaguePoints,
      winChance: winChance ?? this.winChance,
      goldPerSecond: goldPerSecond ?? this.goldPerSecond,
      horsePositions: horsePositions ?? this.horsePositions,
      raceTimeLeft: raceTimeLeft ?? this.raceTimeLeft,
      raceDurationSeconds: raceDurationSeconds ?? this.raceDurationSeconds,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      horses: horses ?? this.horses,
      jockeys: jockeys ?? this.jockeys,
      buildings: buildings ?? this.buildings,
      inventory: inventory ?? this.inventory,
      equippedEquipment: equippedEquipment ?? this.equippedEquipment,
      lastSaved: lastSaved ?? this.lastSaved,
      unlockedLeagueTier: unlockedLeagueTier ?? this.unlockedLeagueTier,
      recentPlacements: recentPlacements ?? this.recentPlacements,
      boostTimeLeft: boostTimeLeft ?? this.boostTimeLeft,
      currentSeasonRace: currentSeasonRace ?? this.currentSeasonRace,
      seasonPoints: seasonPoints ?? this.seasonPoints,
      rivalSeasonPoints: rivalSeasonPoints ?? this.rivalSeasonPoints,
      rivalJockeyNames: rivalJockeyNames ?? this.rivalJockeyNames,
      currentClassIndex: currentClassIndex ?? this.currentClassIndex,
      sponsorActive: sponsorActive ?? this.sponsorActive,
      sponsorPosition: sponsorPosition ?? this.sponsorPosition,
      raceState: raceState ?? this.raceState,
      resultsCountdown: resultsCountdown ?? this.resultsCountdown,
      lastRacePlacement: lastRacePlacement ?? this.lastRacePlacement,
      lastRaceGoldEarned: lastRaceGoldEarned ?? this.lastRaceGoldEarned,
      lastRacePointsEarned: lastRacePointsEarned ?? this.lastRacePointsEarned,
      hasChangedHorseName: hasChangedHorseName ?? this.hasChangedHorseName,
      playerGateNumber: playerGateNumber ?? this.playerGateNumber,
      currentRaceRivalNames: currentRaceRivalNames ?? this.currentRaceRivalNames,
      pendingOfflineGold: pendingOfflineGold ?? this.pendingOfflineGold,
      raceRanks: raceRanks ?? this.raceRanks,
      season: season ?? this.season,
      lastSeasonRank: lastSeasonRank ?? this.lastSeasonRank,
      offlineDurationSeconds: offlineDurationSeconds ?? this.offlineDurationSeconds,
      seasonHistory: seasonHistory ?? this.seasonHistory,
      seasonClassHistory: seasonClassHistory ?? this.seasonClassHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gold': gold,
      'diamonds': diamonds,
      'currentDerbyLeague': currentDerbyLeague,
      'leagueTier': leagueTier,
      'leaguePoints': leaguePoints,
      'winChance': winChance,
      'goldPerSecond': goldPerSecond,
      'horsePositions': horsePositions,
      'raceTimeLeft': raceTimeLeft,
      'raceDurationSeconds': raceDurationSeconds,
      'currentTabIndex': currentTabIndex,
      'horses': horses.map((e) => e.toJson()).toList(),
      'jockeys': jockeys.map((e) => e.toJson()).toList(),
      'buildings': buildings,
      'inventory': inventory.map((e) => e.toJson()).toList(),
      'equippedEquipment': equippedEquipment,
      'lastSaved': lastSaved.toIso8601String(),
      'unlockedLeagueTier': unlockedLeagueTier,
      'recentPlacements': recentPlacements,
      'boostTimeLeft': boostTimeLeft,
      'currentSeasonRace': currentSeasonRace,
      'seasonPoints': seasonPoints,
      'rivalSeasonPoints': rivalSeasonPoints,
      'rivalJockeyNames': rivalJockeyNames,
      'currentClassIndex': currentClassIndex,
      'sponsorActive': sponsorActive,
      'sponsorPosition': sponsorPosition,
      'raceState': raceState,
      'resultsCountdown': resultsCountdown,
      'lastRacePlacement': lastRacePlacement,
      'lastRaceGoldEarned': lastRaceGoldEarned,
      'lastRacePointsEarned': lastRacePointsEarned,
      'hasChangedHorseName': hasChangedHorseName,
      'playerGateNumber': playerGateNumber,
      'currentRaceRivalNames': currentRaceRivalNames,
      'pendingOfflineGold': pendingOfflineGold,
      'raceRanks': raceRanks,
      'season': season,
      'lastSeasonRank': lastSeasonRank,
      'offlineDurationSeconds': offlineDurationSeconds,
      'seasonHistory': seasonHistory,
      'seasonClassHistory': seasonClassHistory,
    };
  }

  factory GameStateModel.fromJson(Map<String, dynamic> json) {
    return GameStateModel(
      gold: (json['gold'] as num?)?.toDouble() ?? 500.0,
      diamonds: (json['diamonds'] as num?)?.toInt() ?? 10,
      currentDerbyLeague: json['currentDerbyLeague'] as String? ?? 'Village League',
      leagueTier: (json['leagueTier'] as num?)?.toInt() ?? 0,
      leaguePoints: (json['leaguePoints'] as num?)?.toDouble() ?? 0.0,
      winChance: (json['winChance'] as num?)?.toDouble() ?? 0.20,
      goldPerSecond: (json['goldPerSecond'] as num?)?.toDouble() ?? 0.0,
      horsePositions: (json['horsePositions'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? 
          const [0.0, 0.0, 0.0, 0.0, 0.0],
      raceTimeLeft: (json['raceTimeLeft'] as num?)?.toInt() ?? 45,
      raceDurationSeconds: (json['raceDurationSeconds'] as num?)?.toInt() ?? 45,
      currentTabIndex: (json['currentTabIndex'] as num?)?.toInt() ?? 0,
      horses: (json['horses'] as List?)
              ?.map((e) => HorseAsset.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          defaultHorses(),
      jockeys: (json['jockeys'] as List?)
              ?.map((e) => JockeyAsset.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          defaultJockeys(),
      buildings: Map<String, int>.from(json['buildings'] as Map? ?? {
        'training_track': 0,
        'medical_center': 0,
        'feed_storage': 0,
        'research_lab': 0,
        'luxury_stable': 0,
      }),
      inventory: (json['inventory'] as List?)
              ?.map((e) => EquipmentItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      equippedEquipment: Map<String, String>.from(json['equippedEquipment'] as Map? ?? {}),
      lastSaved: json['lastSaved'] != null
          ? DateTime.parse(json['lastSaved'] as String)
          : DateTime.now(),
      unlockedLeagueTier: (json['unlockedLeagueTier'] as num?)?.toInt() ?? 0,
      recentPlacements: (json['recentPlacements'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      boostTimeLeft: (json['boostTimeLeft'] as num?)?.toInt() ?? 0,
      currentSeasonRace: (json['currentSeasonRace'] as num?)?.toInt() ?? 1,
      seasonPoints: (json['seasonPoints'] as num?)?.toDouble() ?? 0.0,
      rivalSeasonPoints: (json['rivalSeasonPoints'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 0.0, 0.0],
      rivalJockeyNames: (json['rivalJockeyNames'] as List?)?.map((e) => e as String).toList() ?? const ['Galopping Greg', 'Speedy Sarah', 'Blitzing Bob', 'Thundering Ted'],
      currentClassIndex: (json['currentClassIndex'] as num?)?.toInt() ?? 0,
      sponsorActive: json['sponsorActive'] as bool? ?? false,
      sponsorPosition: (json['sponsorPosition'] as num?)?.toDouble() ?? 1.0,
      raceState: json['raceState'] as String? ?? 'racing',
      resultsCountdown: (json['resultsCountdown'] as num?)?.toInt() ?? 0,
      lastRacePlacement: (json['lastRacePlacement'] as num?)?.toInt() ?? 1,
      lastRaceGoldEarned: (json['lastRaceGoldEarned'] as num?)?.toDouble() ?? 0.0,
      lastRacePointsEarned: (json['lastRacePointsEarned'] as num?)?.toDouble() ?? 0.0,
      hasChangedHorseName: json['hasChangedHorseName'] as bool? ?? false,
      playerGateNumber: (json['playerGateNumber'] as num?)?.toInt() ?? 0,
      currentRaceRivalNames: (json['currentRaceRivalNames'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const ['Thunderbolt', 'Silver Arrow', 'Desert Storm', 'Night Fury'],
      pendingOfflineGold: (json['pendingOfflineGold'] as num?)?.toDouble() ?? 0.0,
      raceRanks: (json['raceRanks'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 2, 3, 4, 5],
      season: (json['season'] as num?)?.toInt() ?? 1,
      lastSeasonRank: (json['lastSeasonRank'] as num?)?.toInt() ?? 0,
      offlineDurationSeconds: (json['offlineDurationSeconds'] as num?)?.toInt() ?? 0,
      seasonHistory: (json['seasonHistory'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      seasonClassHistory: (json['seasonClassHistory'] as List?)?.map((e) => e as String).toList() ?? const [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! GameStateModel) {
      return false;
    }
    return other.gold == gold &&
        other.diamonds == diamonds &&
        other.currentDerbyLeague == currentDerbyLeague &&
        other.leagueTier == leagueTier &&
        other.leaguePoints == leaguePoints &&
        other.winChance == winChance &&
        other.goldPerSecond == goldPerSecond &&
        listEquals(other.horsePositions, horsePositions) &&
        other.raceTimeLeft == raceTimeLeft &&
        other.raceDurationSeconds == raceDurationSeconds &&
        other.currentTabIndex == currentTabIndex &&
        listEquals(other.horses, horses) &&
        listEquals(other.jockeys, jockeys) &&
        mapEquals(other.buildings, buildings) &&
        listEquals(other.inventory, inventory) &&
        mapEquals(other.equippedEquipment, equippedEquipment) &&
        other.lastSaved == lastSaved &&
        other.unlockedLeagueTier == unlockedLeagueTier &&
        listEquals(other.recentPlacements, recentPlacements) &&
        other.boostTimeLeft == boostTimeLeft &&
        other.currentSeasonRace == currentSeasonRace &&
        other.seasonPoints == seasonPoints &&
        listEquals(other.rivalSeasonPoints, rivalSeasonPoints) &&
        listEquals(other.rivalJockeyNames, rivalJockeyNames) &&
        other.currentClassIndex == currentClassIndex &&
        other.sponsorActive == sponsorActive &&
        other.sponsorPosition == sponsorPosition &&
        other.raceState == raceState &&
        other.resultsCountdown == resultsCountdown &&
        other.lastRacePlacement == lastRacePlacement &&
        other.lastRaceGoldEarned == lastRaceGoldEarned &&
        other.lastRacePointsEarned == lastRacePointsEarned &&
        other.hasChangedHorseName == hasChangedHorseName &&
        other.playerGateNumber == playerGateNumber &&
        listEquals(other.currentRaceRivalNames, currentRaceRivalNames) &&
        other.pendingOfflineGold == pendingOfflineGold &&
        listEquals(other.raceRanks, raceRanks) &&
        other.season == season &&
        other.lastSeasonRank == lastSeasonRank &&
        other.offlineDurationSeconds == offlineDurationSeconds &&
        listEquals(other.seasonHistory, seasonHistory) &&
        listEquals(other.seasonClassHistory, seasonClassHistory);
  }

  @override
  int get hashCode {
    return Object.hash(
      gold,
      diamonds,
      currentDerbyLeague,
      leagueTier,
      leaguePoints,
      winChance,
      goldPerSecond,
      Object.hashAll(horsePositions),
      raceTimeLeft,
      raceDurationSeconds,
      currentTabIndex,
      Object.hash(
        Object.hashAll(horses),
        Object.hashAll(jockeys),
        Object.hashAll(buildings.keys),
        Object.hashAll(buildings.values),
        Object.hashAll(inventory),
        Object.hashAll(equippedEquipment.keys),
        Object.hashAll(equippedEquipment.values),
        lastSaved,
        unlockedLeagueTier,
        Object.hash(
          Object.hashAll(recentPlacements),
          boostTimeLeft,
          currentSeasonRace,
          seasonPoints,
          Object.hashAll(rivalSeasonPoints),
          Object.hashAll(rivalJockeyNames),
          currentClassIndex,
          sponsorActive,
          sponsorPosition,
          Object.hash(
            raceState,
            resultsCountdown,
            lastRacePlacement,
            lastRaceGoldEarned,
            lastRacePointsEarned,
            hasChangedHorseName,
            playerGateNumber,
            Object.hashAll(currentRaceRivalNames),
            pendingOfflineGold,
            Object.hashAll(raceRanks),
            season,
            lastSeasonRank,
            offlineDurationSeconds,
            Object.hashAll(seasonHistory),
            Object.hashAll(seasonClassHistory),
          ),
        ),
      ),
    );
  }

  @override
  String toString() {
    return 'GameStateModel(gold: $gold, diamonds: $diamonds, currentDerbyLeague: $currentDerbyLeague, leagueTier: $leagueTier, leaguePoints: $leaguePoints, winChance: $winChance, goldPerSecond: $goldPerSecond, horsePositions: $horsePositions, raceTimeLeft: $raceTimeLeft, raceDurationSeconds: $raceDurationSeconds, currentTabIndex: $currentTabIndex, horses: $horses, jockeys: $jockeys, buildings: $buildings, inventory: $inventory, equippedEquipment: $equippedEquipment, lastSaved: $lastSaved, unlockedLeagueTier: $unlockedLeagueTier, recentPlacements: $recentPlacements, boostTimeLeft: $boostTimeLeft, currentSeasonRace: $currentSeasonRace, seasonPoints: $seasonPoints, rivalSeasonPoints: $rivalSeasonPoints, rivalJockeyNames: $rivalJockeyNames, currentClassIndex: $currentClassIndex, sponsorActive: $sponsorActive, sponsorPosition: $sponsorPosition, raceState: $raceState, resultsCountdown: $resultsCountdown, lastRacePlacement: $lastRacePlacement, lastRaceGoldEarned: $lastRaceGoldEarned, lastRacePointsEarned: $lastRacePointsEarned)';
  }
}
