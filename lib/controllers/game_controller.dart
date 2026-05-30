import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state_model.dart';
import '../main.dart';

class GameNotifier extends Notifier<GameStateModel> {
  Timer? _gameLoopTimer;
  int _tickCount = 0;
  final List<int> _finishedHorses = [];
  final Map<int, Map<String, dynamic>> _leagueStates = {};

  Duration get maxOfflineDuration => const Duration(hours: 2);

  int _matchCapForClass(int classIdx) {
    if (classIdx == 0) return 5;
    if (classIdx == 1 || classIdx == 2) return 10;
    if (classIdx == 3) return 15;
    return 20; // S Class
  }

  /// D=5 horses, C/B=6, A/S=8
  int _raceHorseCount(int classIdx) {
    if (classIdx == 0) return 5;
    if (classIdx <= 2) return 6;
    return 8;
  }

  double _getLeagueModifier(int tier) {
    switch (tier) {
      case 0: return 1.0;
      case 1: return 15.0;
      case 2: return 100.0;
      case 3: return 600.0;
      case 4: return 4000.0;
      case 5: return 4000.0;
      default: return 1.0;
    }
  }

  double getUpgradeCost(String id, int currentLevel) {
    double base = 100.0;
    switch (id) {
      case 'training_track':
        base = 250.0;
        break;
      case 'medical_center':
        base = 1200.0;
        break;
      case 'feed_storage':
        base = 6000.0;
        break;
      case 'research_lab':
        base = 30000.0;
        break;
      case 'luxury_stable':
        base = 150000.0;
        break;
    }
    return base * _getLeagueModifier(state.leagueTier) * math.pow(1.15, currentLevel);
  }

  double getHorseStatUpgradeCost(int tier, int level, String statId) {
    double baseGold = (statId == 'speed' || statId == 'stamina') ? 300.0 : 200.0;
    return baseGold * _getLeagueModifier(tier) * math.pow(1.15, level);
  }

  double getJockeySkillUpgradeCost(int tier, int level, String skillId) {
    double baseGold = (skillId == 'pacing') ? 300.0 : 200.0;
    return baseGold * _getLeagueModifier(tier) * math.pow(1.15, level);
  }

  String getDerbyName(int tier) {
    const names = [
      'Village League',
      'City League',
      'Regional League',
      'National League',
      'Elite League',
      'Legendary League',
    ];
    if (tier < names.length) {
      return names[tier];
    }
    return 'Legendary League';
  }

  DateTime? _lastDiskSaveTime;

  @override
  set state(GameStateModel value) {
    final oldState = stateOrNull;
    bool shouldSaveNow = false;
    if (oldState != null && oldState.leagueTier != value.leagueTier) {
      sharedPrefs.setInt('active_league_tier', value.leagueTier);
      shouldSaveNow = true;
    }
    if (oldState != null && oldState.currentClassIndex != value.currentClassIndex) {
      sharedPrefs.setInt('active_class_index', value.currentClassIndex);
      shouldSaveNow = true;
    }
    if (oldState != null && oldState.unlockedLeagueTier != value.unlockedLeagueTier) {
      sharedPrefs.setInt('unlocked_league_tier', value.unlockedLeagueTier);
      shouldSaveNow = true;
    }
    
    // Save lastSaved timestamp and full state to persistent storage, throttled to once every 5 seconds or immediately on critical changes
    final now = DateTime.now();
    if (shouldSaveNow || _lastDiskSaveTime == null || now.difference(_lastDiskSaveTime!) > const Duration(seconds: 5)) {
      _lastDiskSaveTime = now;
      sharedPrefs.setString('last_saved_time', value.lastSaved.toIso8601String());
      sharedPrefs.setString('game_state_json', jsonEncode(value.toJson()));
      
      final Map<String, Map<String, dynamic>> serialized = _leagueStates.map(
        (key, val) => MapEntry(key.toString(), val),
      );
      sharedPrefs.setString('league_states_json', jsonEncode(serialized));
    }
    
    super.state = value;
  }

  @override
  GameStateModel build() {
    _startGameLoop();

    final now = DateTime.now();

    // 1. Load league states first
    final String? leagueStatesStr = sharedPrefs.getString('league_states_json');
    if (leagueStatesStr != null) {
      try {
        final decoded = jsonDecode(leagueStatesStr) as Map<String, dynamic>;
        _leagueStates.clear();
        decoded.forEach((key, val) {
          final intKey = int.tryParse(key);
          if (intKey != null && val is Map) {
            _leagueStates[intKey] = Map<String, dynamic>.from(val);
          }
        });
      } catch (e) {
        // ignore
      }
    }

    // 2. Load game state from sharedPrefs JSON
    final String? gameStateJson = sharedPrefs.getString('game_state_json');
    if (gameStateJson != null) {
      try {
        final decoded = jsonDecode(gameStateJson) as Map<String, dynamic>;
        var loadedState = GameStateModel.fromJson(decoded);
        loadedState = loadedState.copyWith(
          goldPerSecond: _calculateGoldPerSecond(loadedState.buildings),
        );
        return _applyOfflineProgress(loadedState, now);
      } catch (e) {
        // Fallback to construct initial state if json decoding fails
      }
    }

    final savedTimeString = sharedPrefs.getString('last_saved_time');
    final DateTime initialLastSaved;
    if (savedTimeString != null) {
      initialLastSaved = DateTime.tryParse(savedTimeString) ?? now.subtract(const Duration(minutes: 15));
    } else {
      initialLastSaved = now.subtract(const Duration(minutes: 15));
    }
    final rand = math.Random();
    final savedLeague = sharedPrefs.getInt('active_league_tier') ?? 0;
    final savedClass = sharedPrefs.getInt('active_class_index') ?? 0;
    final savedUnlocked = sharedPrefs.getInt('unlocked_league_tier') ?? 0;
    final savedLeagueName = getDerbyName(savedLeague);
    final initialWinChance = _calculateWinChance(
      GameStateModel.defaultHorses(),
      GameStateModel.defaultJockeys(),
      savedLeague,
      const [],
      const {},
      const {
        'training_track': 0,
        'medical_center': 0,
        'feed_storage': 0,
        'research_lab': 0,
        'luxury_stable': 0,
      },
      classIdx: savedClass,
    );
    final int initCount = _raceHorseCount(savedClass);
    final initialRivalNames = _pickRaceRivalNames(rand, count: initCount - 1);
    final initialRanks = _rollRaceRanks(initialWinChance, rand, count: initCount);

    final initialState = GameStateModel(
      gold: 500.0,
      diamonds: 10,
      currentDerbyLeague: savedLeagueName,
      leagueTier: savedLeague,
      leaguePoints: 0.0,
      winChance: initialWinChance,
      goldPerSecond: 0.0,
      horsePositions: List.filled(initCount, 0.0),
      raceTimeLeft: 450,
      raceDurationSeconds: 45,
      currentTabIndex: 0,
      horses: GameStateModel.defaultHorses(),
      jockeys: GameStateModel.defaultJockeys(),
      buildings: const {
        'training_track': 0,
        'medical_center': 0,
        'feed_storage': 0,
        'research_lab': 0,
        'luxury_stable': 0,
      },
      inventory: const [],
      equippedEquipment: const {},
      lastSaved: initialLastSaved,
      unlockedLeagueTier: savedUnlocked,
      recentPlacements: const [],
      boostTimeLeft: 0,
      currentSeasonRace: 1,
      seasonPoints: 0.0,
      rivalSeasonPoints: List.filled(initCount - 1, 0.0),
      rivalJockeyNames: initialRivalNames,
      currentClassIndex: savedClass,
      sponsorActive: false,
      sponsorPosition: 1.0,
      raceState: 'racing',
      resultsCountdown: 0,
      lastRacePlacement: 1,
      lastRaceGoldEarned: 0.0,
      lastRacePointsEarned: 0.0,
      hasChangedHorseName: false,
      playerGateNumber: rand.nextInt(initCount),
      currentRaceRivalNames: initialRivalNames,
      pendingOfflineGold: 0.0,
      raceRanks: initialRanks,
      season: 1,
      lastSeasonRank: 0,
      offlineDurationSeconds: 0,
      seasonHistory: const [],
      seasonClassHistory: const [],
    );

    return _applyOfflineProgress(initialState, now);
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _tick();
    });

    ref.onDispose(() {
      _gameLoopTimer?.cancel();
      // Write one last time on dispose
      sharedPrefs.setString('last_saved_time', state.lastSaved.toIso8601String());
    });
  }

  List<int> _rollRaceRanks(double winChance, math.Random random, {int count = 5}) {
    final ranks = List<int>.filled(count, 0);
    final roll = random.nextDouble() * 100.0;
    final List<int> allRanks = List.generate(count, (i) => i + 1);
    final bool canWin1st = !(winChance > 0.0 && winChance <= 0.25);
    if (canWin1st && roll < winChance * 100.0) {
      ranks[0] = 1;
      final otherRanks = allRanks.sublist(1)..shuffle(random);
      for (int i = 1; i < count; i++) {
        ranks[i] = otherRanks[i - 1];
      }
    } else {
      final winnerRivalIndex = random.nextInt(count - 1) + 1;
      ranks[winnerRivalIndex] = 1;
      final playerRank = random.nextInt(count - 1) + 2;
      ranks[0] = playerRank;
      final remainingRanks = allRanks.sublist(1)..remove(playerRank);
      remainingRanks.shuffle(random);
      int remIdx = 0;
      for (int i = 1; i < count; i++) {
        if (i != winnerRivalIndex) {
          ranks[i] = remainingRanks[remIdx++];
        }
      }
    }
    return ranks;
  }

  void _tick() {
    _tickCount++;
    final now = DateTime.now();
    final random = math.Random();

    // 1. Decrement boost time left every 10 ticks (1 second)
    int currentBoostTime = state.boostTimeLeft;
    if (currentBoostTime > 0 && _tickCount % 10 == 0) {
      currentBoostTime = math.max(0, currentBoostTime - 1);
    }

    // 2. Accumulate passive gold (0.1x per tick)
    final bool hasVip = state.equippedEquipment['vip_pass'] == 'active';
    final double vipMultiplier = hasVip ? 2.0 : 1.0;
    final double boostMultiplier = currentBoostTime > 0 ? 2.0 : 1.0;
    final double passiveGoldSec = state.goldPerSecond * math.pow(10.0, state.leagueTier) * vipMultiplier * boostMultiplier;
    double currentGold = state.gold + (passiveGoldSec * 0.1);

    // Active background progression for inactive unlocked leagues
    double backgroundGoldEarned = 0.0;
    for (int tier = 0; tier <= state.unlockedLeagueTier; tier++) {
      if (tier == state.leagueTier) continue;
      if (!_leagueStates.containsKey(tier)) {
        _initializeLeagueState(tier, state);
      }
      final Map<String, dynamic> leagueState = Map<String, dynamic>.from(_leagueStates[tier]!);
      int bgTicks = (leagueState['bgTicks'] as int? ?? 0) + 1;
      if (bgTicks >= 500) {
        bgTicks = 0;
        backgroundGoldEarned += _simulateBackgroundMatch(tier, leagueState, state);
      }
      leagueState['bgTicks'] = bgTicks;
      _leagueStates[tier] = leagueState;
    }
    currentGold += backgroundGoldEarned;

    // 3. Sponsor Movement & Spawning
    bool currentSponsorActive = state.sponsorActive;
    double currentSponsorPos = state.sponsorPosition;

    if (!currentSponsorActive) {
      if (random.nextDouble() < 0.003) {
        currentSponsorActive = true;
        currentSponsorPos = 1.0;
      }
    } else {
      currentSponsorPos -= 0.006;
      if (currentSponsorPos < -0.2) {
        currentSponsorActive = false;
        currentSponsorPos = 1.0;
      }
    }

    // 4. Race Logic
    String currentRaceState = state.raceState;
    int currentRaceTimeLeft = state.raceTimeLeft;
    int currentResultsCountdown = state.resultsCountdown;
    List<double> currentPositions = List.from(state.horsePositions);

    double lastRaceGold = state.lastRaceGoldEarned;
    double lastRacePoints = state.lastRacePointsEarned;
    int lastRaceRank = state.lastRacePlacement;

    List<int> recent = List.from(state.recentPlacements);
    double playerPoints = state.seasonPoints;
    List<double> rivalPoints = List.from(state.rivalSeasonPoints);
    int currentSeasonRaceNum = state.currentSeasonRace;
    int currentPlayerGate = state.playerGateNumber;
    List<String> currentRivalNames = List.from(state.currentRaceRivalNames);
    List<int> nextRanks = state.raceRanks;

    int nextSeason = state.season;
    int nextLastSeasonRank = state.lastSeasonRank;
    List<int> nextHistory = state.seasonHistory;
    List<String> nextClassHistory = state.seasonClassHistory;
    int nextClassIndex = state.currentClassIndex;
    int nextLeagueTier = state.leagueTier;
    String nextLeagueName = state.currentDerbyLeague;
    double nextWinChance = state.winChance;
    double nextGoldPerSec = state.goldPerSecond;
    int nextUnlocked = state.unlockedLeagueTier;

    if (currentRaceState == 'racing') {
      if (currentPositions.every((p) => p == 0.0)) {
        _finishedHorses.clear();
      }
      currentRaceTimeLeft -= 1;

      // ═══════════════════════════════════════════════
      //  3-PHASE DRAMA ENGINE
      //  450 ticks = 45 seconds  (100 ms / tick)
      //  Phase 1: ticks 450→301  (first 15s)  – Chaotic Burst
      //  Phase 2: ticks 300→101  (next 20s)   – Rubber-Band Pack
      //  Phase 3: ticks 100→0    (final 10s)  – Destiny Sprint
      // ═══════════════════════════════════════════════

      // Find the pre-determined winner's horse index (rank == 1)
      final int winnerIndex = state.raceRanks.indexOf(1);
      final int t = currentRaceTimeLeft; // ticks remaining

      if (t > 300) {
        // ── PHASE 1: Chaotic Burst (first 15s) ──────────────────────────
        for (int i = 0; i < currentPositions.length; i++) {
          // Base speed: all horses move at roughly the same pace
          final double base = 0.0021;
          // Large random jitter creates chaotic ordering
          final double chaos = (random.nextDouble() * 0.0055) - 0.0025;
          // Very slight bias so winner doesn't fall too far behind
          final double winnerBias = (i == winnerIndex) ? 0.0003 : 0.0;
          currentPositions[i] = (currentPositions[i] + base + chaos + winnerBias)
              .clamp(0.0, 0.88); // cap at 88% so phase-3 sprint matters
        }
      } else if (t > 100) {
        // ── PHASE 2: Rubber-Band Pack (middle 20s) ──────────────────────
        final double packCenter =
            currentPositions.reduce((a, b) => a + b) / currentPositions.length;

        for (int i = 0; i < currentPositions.length; i++) {
          // Base advance keeps everyone moving forward
          final double base = 0.0018;
          // Rubber-band: pull toward pack center (positive = behind, negative = ahead)
          final double rubberBand = (packCenter - currentPositions[i]) * 0.028;
          // Organic jitter causes constant overtaking
          final double jitter = (random.nextDouble() * 0.005) - 0.0025;
          // Tiny winner bias — just enough to keep it in the mix, not leading
          final double winnerBias = (i == winnerIndex) ? 0.00025 : 0.0;

          currentPositions[i] = (currentPositions[i] + base + rubberBand + jitter + winnerBias)
              .clamp(0.0, 0.92); // cap so phase-3 sprint still matters
        }

        // Ensure the pack spread never exceeds 0.10 (ultra-tight cluster)
        final double packMin = currentPositions.reduce(math.min);
        final double packMax = currentPositions.reduce(math.max);
        if (packMax - packMin > 0.10) {
          for (int i = 0; i < currentPositions.length; i++) {
            currentPositions[i] = packCenter +
                (currentPositions[i] - packCenter) * 0.85;
          }
        }
      } else {
        // ── PHASE 3: Destiny Sprint (final 10s) ─────────────────────────
        final double progress = 1.0 - (t / 100.0); // 0.0 → 1.0
        for (int i = 0; i < currentPositions.length; i++) {
          final int rank = state.raceRanks[i];
          if (i == winnerIndex) {
            // Winner: massive acceleration burst — from wherever it is, surges to 1.0
            final double sprint = 0.010 + progress * 0.008;
            currentPositions[i] = (currentPositions[i] + sprint).clamp(0.0, 1.0);
          } else {
            // Non-winners: sprint speed scaled by rank, but allowed to fully cross the line
            final double sprint = 0.002 + (5 - rank) * 0.0015;
            final double jitter = (random.nextDouble() * 0.002) - 0.001;
            currentPositions[i] = (currentPositions[i] + sprint + jitter).clamp(0.0, 1.0);
          }
        }
      }

      // Track horses crossing the finish line in real-time
      for (int i = 0; i < currentPositions.length; i++) {
        if (currentPositions[i] >= 1.0 && !_finishedHorses.contains(i)) {
          _finishedHorses.add(i);
        }
      }

      // ── Race End Check: only end when the PLAYER's horse crosses the line ──
      if (currentRaceTimeLeft <= 0 || _finishedHorses.contains(0)) {
        final int horseCount = currentPositions.length;
        // Ensure any remaining horses that crossed in this tick are added
        for (int i = 0; i < horseCount; i++) {
          if (currentPositions[i] >= 1.0 && !_finishedHorses.contains(i)) {
            _finishedHorses.add(i);
          }
        }
        // If timed out or some didn't finish, add them sorted by position
        if (_finishedHorses.length < horseCount) {
          final List<MapEntry<int, double>> unfinished = [];
          for (int i = 0; i < horseCount; i++) {
            if (!_finishedHorses.contains(i)) {
              unfinished.add(MapEntry(i, currentPositions[i]));
            }
          }
          unfinished.sort((a, b) => b.value.compareTo(a.value));
          for (final entry in unfinished) {
            _finishedHorses.add(entry.key);
          }
        }

        final List<int> actualRanks = List.filled(horseCount, 0);
        for (int rankIndex = 0; rankIndex < horseCount; rankIndex++) {
          final int horseId = _finishedHorses[rankIndex];
          actualRanks[horseId] = rankIndex + 1;
        }

        final int playerRank = actualRanks[0];

        // Class D reward matrix: 1st=500, 2nd=400, 3rd=300, 4th=200, 5th=100
        double baseGold = 100.0;
        if (playerRank == 1) {
          baseGold = 500.0;
        } else if (playerRank == 2) {
          baseGold = 400.0;
        } else if (playerRank == 3) {
          baseGold = 300.0;
        } else if (playerRank == 4) {
          baseGold = 200.0;
        }

        double goldEarned = baseGold * math.pow(10.0, state.leagueTier) * boostMultiplier;
        currentGold += goldEarned;

        double pointsForRank(int rank) {
          if (rank == 1) return 30.0;
          if (rank == 2) return 15.0;
          if (rank == 3) return 5.0;
          return 0.0;
        }

        double playerPointsEarned = pointsForRank(playerRank);
        playerPoints += playerPointsEarned;

        for (int i = 1; i < currentPositions.length; i++) {
          int rank = actualRanks[i];
          rivalPoints[i - 1] += pointsForRank(rank);
        }

        recent.insert(0, playerRank);
        if (recent.length > 5) recent.removeLast();

        currentRaceState = 'results';
        currentResultsCountdown = 50;
        lastRaceGold = goldEarned;
        lastRacePoints = playerPointsEarned;
        lastRaceRank = playerRank;
      }
    } else if (currentRaceState == 'results') {
      currentResultsCountdown -= 1;
      if (currentResultsCountdown <= 0) {
        final int matchCap = _matchCapForClass(state.currentClassIndex);
        if (currentSeasonRaceNum < matchCap) {
          currentSeasonRaceNum += 1;
          currentRaceState = 'racing';
          currentRaceTimeLeft = 450;
          currentPositions = List.filled(state.horsePositions.length, 0.0);
          currentPlayerGate = random.nextInt(state.horsePositions.length);
          currentRivalNames = state.currentRaceRivalNames;
          nextRanks = _rollRaceRanks(state.winChance, random, count: state.horsePositions.length);
        } else {
          final int finalRank = rivalPoints.where((rp) => rp > playerPoints).length + 1;
          final bool isPlayerFirst = rivalPoints.every((rp) => playerPoints >= rp);
          
          nextSeason = state.season + 1;
          nextLastSeasonRank = finalRank;
          
          final updatedHistory = List<int>.from(state.seasonHistory)..add(finalRank);
          if (updatedHistory.length > 10) {
            updatedHistory.removeAt(0);
          }
          nextHistory = updatedHistory;

          final updatedClassHistory = List<String>.from(state.seasonClassHistory)
            ..add('${state.leagueTier},${state.currentClassIndex}');
          if (updatedClassHistory.length > 10) {
            updatedClassHistory.removeAt(0);
          }
          nextClassHistory = updatedClassHistory;

          if (isPlayerFirst && !(state.leagueTier == 5 && state.currentClassIndex == 4)) {
            final double cost = 150.0 * math.pow(10.0, state.leagueTier) * (state.currentClassIndex + 1);
            if (currentGold >= cost) {
              currentGold -= cost;
              if (nextClassIndex < 4) {
                nextClassIndex++;
              }
              nextLeagueName = getDerbyName(nextLeagueTier);
              nextWinChance = _calculateWinChance(
                state.horses,
                state.jockeys,
                nextLeagueTier,
                state.inventory,
                state.equippedEquipment,
                state.buildings,
                classIdx: nextClassIndex,
              );
              nextGoldPerSec = _calculateGoldPerSecond(state.buildings);
              nextUnlocked = math.max(nextUnlocked, nextLeagueTier);
            }
          }

          final int nextHorseCount = _raceHorseCount(nextClassIndex);
          final newRivals = _pickRaceRivalNames(random, count: nextHorseCount - 1);
          final nextRanksPerm = _rollRaceRanks(nextWinChance, random, count: nextHorseCount);

          playerPoints = 0.0;
          rivalPoints = List.filled(nextHorseCount - 1, 0.0);
          currentRivalNames = newRivals;
          currentSeasonRaceNum = 1;
          currentRaceState = 'racing';
          currentRaceTimeLeft = 450;
          currentPositions = List.filled(nextHorseCount, 0.0);
          nextRanks = nextRanksPerm;
          currentPlayerGate = random.nextInt(nextHorseCount);
        }
      }
    }

    state = state.copyWith(
      gold: currentGold,
      boostTimeLeft: currentBoostTime,
      sponsorActive: currentSponsorActive,
      sponsorPosition: currentSponsorPos,
      raceState: currentRaceState,
      raceTimeLeft: currentRaceTimeLeft,
      resultsCountdown: currentResultsCountdown,
      horsePositions: currentPositions,
      lastRaceGoldEarned: lastRaceGold,
      lastRacePointsEarned: lastRacePoints,
      lastRacePlacement: lastRaceRank,
      recentPlacements: recent,
      seasonPoints: playerPoints,
      rivalSeasonPoints: rivalPoints,
      currentSeasonRace: currentSeasonRaceNum,
      playerGateNumber: currentPlayerGate,
      currentRaceRivalNames: currentRivalNames,
      rivalJockeyNames: currentRivalNames,
      raceRanks: nextRanks,
      season: nextSeason,
      lastSeasonRank: nextLastSeasonRank,
      seasonHistory: nextHistory,
      seasonClassHistory: nextClassHistory,
      currentClassIndex: nextClassIndex,
      leagueTier: nextLeagueTier,
      currentDerbyLeague: nextLeagueName,
      winChance: nextWinChance,
      goldPerSecond: nextGoldPerSec,
      unlockedLeagueTier: nextUnlocked,
      lastSaved: now,
    );
  }

  void activateBoost() {
    state = state.copyWith(
      boostTimeLeft: 900,
    );
  }

  /// At ismini yeniden adlandırır.
  void renamePlayerHorse(int index, String newName) {
    if (newName.trim().isEmpty || index < 0 || index >= state.horses.length) {
      return;
    }
    final newHorses = List<HorseAsset>.from(state.horses);
    newHorses[index] = newHorses[index].copyWith(name: newName.trim());
    state = state.copyWith(
      horses: newHorses,
      hasChangedHorseName: true,
      lastSaved: DateTime.now(),
    );
  }

  /// Çevrimdışı kazancı toplar. [doubled] = true ise reklam izlenerek 2 katı alınır.
  void collectOfflineGold({bool doubled = false}) {
    if (doubled) {
      state = state.copyWith(
        gold: state.gold + state.pendingOfflineGold,
        pendingOfflineGold: 0.0,
        offlineDurationSeconds: 0,
        lastSaved: DateTime.now(),
      );
    } else {
      state = state.copyWith(
        pendingOfflineGold: 0.0,
        offlineDurationSeconds: 0,
        lastSaved: DateTime.now(),
      );
    }
  }

  double getSponsorRewardGold() {
    final bool hasVip = state.equippedEquipment['vip_pass'] == 'active';
    final double vipMultiplier = hasVip ? 2.0 : 1.0;
    final double boostMultiplier = state.boostTimeLeft > 0 ? 2.0 : 1.0;
    final double passiveGoldSec = state.goldPerSecond * math.pow(10.0, state.leagueTier) * vipMultiplier * boostMultiplier;
    return math.max(60.0 * passiveGoldSec, state.gold * 0.10);
  }

  void claimSponsorReward() {
    double rewardGold = getSponsorRewardGold();
    state = state.copyWith(
      gold: state.gold + rewardGold,
      sponsorActive: false,
      sponsorPosition: 1.0,
    );
  }

  void rejectSponsorReward() {
    state = state.copyWith(
      sponsorActive: false,
      sponsorPosition: 1.0,
    );
  }

  void pauseGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = null;
  }

  void resumeGameLoop() {
    if (_gameLoopTimer == null) {
      _startGameLoop();
    }
  }


  double getDivisionPromotionCost() {
    return 150.0 * math.pow(10.0, state.leagueTier) * (state.currentClassIndex + 1);
  }

  bool promoteDivision() {
    if (state.currentClassIndex == 4) return false;
    final double cost = getDivisionPromotionCost();
    if (state.gold >= cost) {
      int nextClassIndex = state.currentClassIndex + 1;
      int nextLeagueTier = state.leagueTier;
      
      final String nextLeagueName = getDerbyName(nextLeagueTier);
      final double newWinChance = _calculateWinChance(
        state.horses,
        state.jockeys,
        nextLeagueTier,
        state.inventory,
        state.equippedEquipment,
        state.buildings,
        classIdx: nextClassIndex,
      );

      final int promoCount = _raceHorseCount(nextClassIndex);
      final newRivals = _pickRaceRivalNames(math.Random(), count: promoCount - 1);
      final nextRanks = _rollRaceRanks(newWinChance, math.Random(), count: promoCount);

      state = state.copyWith(
        gold: state.gold - cost,
        currentClassIndex: nextClassIndex,
        leagueTier: nextLeagueTier,
        currentDerbyLeague: nextLeagueName,
        winChance: newWinChance,
        unlockedLeagueTier: math.max(state.unlockedLeagueTier, nextLeagueTier),
        seasonPoints: 0.0,
        rivalSeasonPoints: List.filled(promoCount - 1, 0.0),
        rivalJockeyNames: newRivals,
        currentRaceRivalNames: newRivals,
        currentSeasonRace: 1,
        raceState: 'racing',
        raceTimeLeft: 450,
        horsePositions: List.filled(promoCount, 0.0),
        raceRanks: nextRanks,
        season: state.season + 1,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  void restartSeasonWithoutPromotion() {
    final int cnt = _raceHorseCount(state.currentClassIndex);
    final newRivals = _pickRaceRivalNames(math.Random(), count: cnt - 1);
    final nextRanks = _rollRaceRanks(state.winChance, math.Random(), count: cnt);

    state = state.copyWith(
      seasonPoints: 0.0,
      rivalSeasonPoints: List.filled(cnt - 1, 0.0),
      rivalJockeyNames: newRivals,
      currentRaceRivalNames: newRivals,
      currentSeasonRace: 1,
      raceState: 'racing',
      raceTimeLeft: 450,
      horsePositions: List.filled(cnt, 0.0),
      raceRanks: nextRanks,
      season: state.season + 1,
      lastSaved: DateTime.now(),
    );
  }

  void completeSeasonAndReset() {
    restartSeasonWithoutPromotion();
  }

  void setActiveLeague(int tier) {
    if (tier > state.unlockedLeagueTier) {
      return;
    }
    
    _saveLeagueState(state.leagueTier);

    if (_leagueStates.containsKey(tier)) {
      final saved = _leagueStates[tier]!;
      final savedBuildings = (saved['buildings'] as Map?)?.cast<String, int>() ?? const {
        'training_track': 0,
        'medical_center': 0,
        'feed_storage': 0,
        'research_lab': 0,
        'luxury_stable': 0,
      };

      state = state.copyWith(
        leagueTier: tier,
        currentDerbyLeague: getDerbyName(tier),
        currentClassIndex: saved['currentClassIndex'] as int,
        currentSeasonRace: saved['currentSeasonRace'] as int,
        seasonPoints: saved['seasonPoints'] as double,
        rivalSeasonPoints: (saved['rivalSeasonPoints'] as List).cast<double>(),
        recentPlacements: (saved['recentPlacements'] as List).cast<int>(),
        horsePositions: (saved['horsePositions'] as List).cast<double>(),
        raceTimeLeft: saved['raceTimeLeft'] as int,
        raceState: saved['raceState'] as String,
        raceRanks: (saved['raceRanks'] as List).cast<int>(),
        currentRaceRivalNames: (saved['currentRaceRivalNames'] as List).cast<String>(),
        rivalJockeyNames: (saved['rivalJockeyNames'] as List).cast<String>(),
        playerGateNumber: saved['playerGateNumber'] as int,
        winChance: saved['winChance'] as double,
        resultsCountdown: saved['resultsCountdown'] as int,
        lastRacePlacement: saved['lastRacePlacement'] as int,
        lastRaceGoldEarned: saved['lastRaceGoldEarned'] as double,
        lastRacePointsEarned: saved['lastRacePointsEarned'] as double,
        season: (saved['season'] as int?) ?? 1,
        seasonHistory: (saved['seasonHistory'] as List?)?.cast<int>() ?? const [],
        seasonClassHistory: (saved['seasonClassHistory'] as List?)?.cast<String>() ?? const [],
        buildings: savedBuildings,
        goldPerSecond: _calculateGoldPerSecond(savedBuildings),
      );
      return;
    }

    final newLeagueName = getDerbyName(tier);
    final defaultBuildings = const {
      'training_track': 0,
      'medical_center': 0,
      'feed_storage': 0,
      'research_lab': 0,
      'luxury_stable': 0,
    };
    final double newWinChance = _calculateWinChance(
      state.horses,
      state.jockeys,
      tier,
      state.inventory,
      state.equippedEquipment,
      defaultBuildings,
      classIdx: 0,
    );

    // setActiveLeague always resets to class D (index 0) for the chosen tier
    final int cnt = _raceHorseCount(0);
    final nextRanks = _rollRaceRanks(newWinChance, math.Random(), count: cnt);
    final newRivals = _pickRaceRivalNames(math.Random(), count: cnt - 1);

    state = state.copyWith(
      leagueTier: tier,
      currentDerbyLeague: newLeagueName,
      winChance: newWinChance,
      seasonPoints: 0.0,
      rivalSeasonPoints: List.filled(cnt - 1, 0.0),
      rivalJockeyNames: newRivals,
      currentRaceRivalNames: newRivals,
      currentSeasonRace: 1,
      currentClassIndex: 0,
      raceState: 'racing',
      raceTimeLeft: 450,
      horsePositions: List.filled(cnt, 0.0),
      raceRanks: nextRanks,
      season: 1,
      seasonHistory: const [],
      seasonClassHistory: const [],
      buildings: defaultBuildings,
      goldPerSecond: _calculateGoldPerSecond(defaultBuildings),
      lastSaved: DateTime.now(),
    );
  }

  double getLeagueUnlockCost(int tier) {
    switch (tier) {
      case 1:
        return 50000.0;
      case 2:
        return 250000.0;
      case 3:
        return 1250000.0;
      case 4:
        return 7500000.0;
      case 5:
        return 7500000.0;
      default:
        return 0.0;
    }
  }

  bool unlockNextLeague() {
    int nextTier = state.unlockedLeagueTier + 1;
    if (nextTier > 5) {
      return false;
    }
    double cost = getLeagueUnlockCost(nextTier);
    if (state.gold >= cost) {
      _saveLeagueState(state.leagueTier);

      final newUnlocked = nextTier;
      final newActiveLeague = nextTier;
      final newLeagueName = getDerbyName(newActiveLeague);
      
      final defaultBuildings = const {
        'training_track': 0,
        'medical_center': 0,
        'feed_storage': 0,
        'research_lab': 0,
        'luxury_stable': 0,
      };

      final double newWinChance = _calculateWinChance(
        state.horses,
        state.jockeys,
        newActiveLeague,
        state.inventory,
        state.equippedEquipment,
        defaultBuildings,
        classIdx: 0,
      );

      // unlockNextLeague always starts at class D (index 0)
      final int cnt = _raceHorseCount(0);
      final nextRanks = _rollRaceRanks(newWinChance, math.Random(), count: cnt);
      final newRivals = _pickRaceRivalNames(math.Random(), count: cnt - 1);

      state = state.copyWith(
        gold: state.gold - cost,
        unlockedLeagueTier: newUnlocked,
        leagueTier: newActiveLeague,
        currentDerbyLeague: newLeagueName,
        currentClassIndex: 0,
        winChance: newWinChance,
        seasonPoints: 0.0,
        rivalSeasonPoints: List.filled(cnt - 1, 0.0),
        rivalJockeyNames: newRivals,
        currentRaceRivalNames: newRivals,
        currentSeasonRace: 1,
        raceState: 'racing',
        raceTimeLeft: 450,
        horsePositions: List.filled(cnt, 0.0),
        raceRanks: nextRanks,
        season: 1,
        seasonHistory: const [],
        seasonClassHistory: const [],
        buildings: defaultBuildings,
        goldPerSecond: _calculateGoldPerSecond(defaultBuildings),
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  bool upgradeHorseStat(int horseIndex, String statId) {
    if (horseIndex < 0 || horseIndex >= state.horses.length) {
      return false;
    }
    final horse = state.horses[horseIndex];
    if (horse.associatedLeagueTier > state.leagueTier) {
      return false; // Locked
    }

    final int level = horse.stats[statId] ?? 0;
    if (level >= 50) {
      return false; // Max level cap
    }
    final double cost = getHorseStatUpgradeCost(horse.associatedLeagueTier, level, statId);

    if (state.gold >= cost) {
      final newStats = Map<String, int>.from(horse.stats);
      newStats[statId] = level + 1;

      final updatedHorse = horse.copyWith(stats: newStats);
      final newHorses = List<HorseAsset>.from(state.horses);
      newHorses[horseIndex] = updatedHorse;

      final double newWinChance = _calculateWinChance(
        newHorses,
        state.jockeys,
        state.leagueTier,
        state.inventory,
        state.equippedEquipment,
        state.buildings,
        classIdx: state.currentClassIndex,
      );

      state = state.copyWith(
        gold: state.gold - cost,
        horses: newHorses,
        winChance: newWinChance,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  bool upgradeJockeySkill(int jockeyIndex, String skillId) {
    if (jockeyIndex < 0 || jockeyIndex >= state.jockeys.length) {
      return false;
    }
    final jockey = state.jockeys[jockeyIndex];
    if (jockey.associatedLeagueTier > state.leagueTier) {
      return false; // Locked
    }

    final int level = jockey.skills[skillId] ?? 0;
    if (level >= 50) {
      return false; // Max level cap
    }
    final double cost = getJockeySkillUpgradeCost(jockey.associatedLeagueTier, level, skillId);

    if (state.gold >= cost) {
      final newSkills = Map<String, int>.from(jockey.skills);
      newSkills[skillId] = level + 1;

      final updatedJockey = jockey.copyWith(skills: newSkills);
      final newJockeys = List<JockeyAsset>.from(state.jockeys);
      newJockeys[jockeyIndex] = updatedJockey;

      final double newWinChance = _calculateWinChance(
        state.horses,
        newJockeys,
        state.leagueTier,
        state.inventory,
        state.equippedEquipment,
        state.buildings,
        classIdx: state.currentClassIndex,
      );

      state = state.copyWith(
        gold: state.gold - cost,
        jockeys: newJockeys,
        winChance: newWinChance,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  bool buyPremiumHorse(int tier) {
    const int cost = 15; // 15 Diamonds
    if (state.diamonds >= cost) {
      final random = math.Random();
      final names = [
        'Pegasus Elite', 'Shadow Legend', 'Golden Emperor', 
        'Star Chaser', 'Midnight Mystic', 'Titan Legend', 
        'Elmas Rüzgarı', 'Fırtına Pençesi'
      ];
      final name = names[random.nextInt(names.length)];
      final newHorse = HorseAsset(
        id: 'h_prem_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        associatedLeagueTier: tier,
        currentStars: 5,
        duplicateCardCount: 0,
        stats: const {
          'speed': 0,
          'acceleration': 0,
          'stamina': 0,
          'focus': 0,
          'temper': 0,
          'cornering': 0,
        },
      );
      final newHorses = List<HorseAsset>.from(state.horses)..add(newHorse);
      state = state.copyWith(
        diamonds: state.diamonds - cost,
        horses: newHorses,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  bool buyPremiumJockey(int tier) {
    const int cost = 15; // 15 Diamonds
    if (state.diamonds >= cost) {
      final random = math.Random();
      final names = [
        'Legendary Luke', 'Master Maverick', 'Apex Rider', 
        'Star Whisperer', 'Shadow Racer', 'Crown Prince',
        'Elmas Jokey', 'Fırtına Süvarisi'
      ];
      final name = names[random.nextInt(names.length)];
      final newJockey = JockeyAsset(
        id: 'j_prem_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        associatedLeagueTier: tier,
        currentStars: 5,
        duplicateCardCount: 0,
        skills: const {
          'tactics': 0,
          'pacing': 0,
          'reflexes': 0,
        },
      );
      final newJockeys = List<JockeyAsset>.from(state.jockeys)..add(newJockey);
      state = state.copyWith(
        diamonds: state.diamonds - cost,
        jockeys: newJockeys,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  void assignHorse(String horseId, int tier) {
    final idx = state.horses.indexWhere((h) => h.id == horseId);
    if (idx == -1) return;

    final newHorses = List<HorseAsset>.from(state.horses);
    final temp = newHorses[tier];
    newHorses[tier] = newHorses[idx];
    newHorses[idx] = temp;

    final double newWinChance = _calculateWinChance(
      newHorses,
      state.jockeys,
      state.leagueTier,
      state.inventory,
      state.equippedEquipment,
      state.buildings,
      classIdx: state.currentClassIndex,
    );

    state = state.copyWith(
      horses: newHorses,
      winChance: newWinChance,
      lastSaved: DateTime.now(),
    );
  }

  void assignJockey(String jockeyId, int tier) {
    final idx = state.jockeys.indexWhere((j) => j.id == jockeyId);
    if (idx == -1) return;

    final newJockeys = List<JockeyAsset>.from(state.jockeys);
    final temp = newJockeys[tier];
    newJockeys[tier] = newJockeys[idx];
    newJockeys[idx] = temp;

    final double newWinChance = _calculateWinChance(
      state.horses,
      newJockeys,
      state.leagueTier,
      state.inventory,
      state.equippedEquipment,
      state.buildings,
      classIdx: state.currentClassIndex,
    );

    state = state.copyWith(
      jockeys: newJockeys,
      winChance: newWinChance,
      lastSaved: DateTime.now(),
    );
  }

  bool upgradeBuilding(String buildingId) {
    final buildings = Map<String, int>.from(state.buildings);
    final int currentLevel = buildings[buildingId] ?? 0;
    final double cost = getUpgradeCost(buildingId, currentLevel);

    if (state.gold >= cost) {
      final newBuildings = Map<String, int>.from(buildings);
      newBuildings[buildingId] = currentLevel + 1;

      final double newGoldPerSec = _calculateGoldPerSecond(newBuildings);
      final double newWinChance = _calculateWinChance(
        state.horses,
        state.jockeys,
        state.leagueTier,
        state.inventory,
        state.equippedEquipment,
        newBuildings,
        classIdx: state.currentClassIndex,
      );

      state = state.copyWith(
        gold: state.gold - cost,
        buildings: newBuildings,
        goldPerSecond: newGoldPerSec,
        winChance: newWinChance,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  void setTabIndex(int index) {
    state = state.copyWith(currentTabIndex: index);
  }

  // League Gacha Chest Openings
  Map<String, dynamic>? openLeagueChest(int chestTier, bool withGold) {
    if (chestTier > state.leagueTier) {
      return null; // Chest is still locked
    }

    final double goldCost = 1000.0 * math.pow(10.0, chestTier);
    final int diamondCost = 3 + chestTier * 2;

    if (withGold) {
      if (state.gold < goldCost) {
        return null;
      }
    } else {
      if (state.diamonds < diamondCost) {
        return null;
      }
    }

    final random = math.Random();
    final bool isHorseCard = random.nextBool();
    String cardName = '';
    int stars = 1;

    List<HorseAsset> newHorses = List.from(state.horses);
    List<JockeyAsset> newJockeys = List.from(state.jockeys);

    if (isHorseCard) {
      final horse = state.horses[chestTier];
      final updatedHorse = horse.copyWith(
        duplicateCardCount: horse.duplicateCardCount + 1,
      );
      newHorses[chestTier] = updatedHorse;
      cardName = horse.name;
      stars = horse.currentStars;
    } else {
      final jockey = state.jockeys[chestTier];
      final updatedJockey = jockey.copyWith(
        duplicateCardCount: jockey.duplicateCardCount + 1,
      );
      newJockeys[chestTier] = updatedJockey;
      cardName = jockey.name;
      stars = jockey.currentStars;
    }

    final double newWinChance = _calculateWinChance(
      newHorses,
      newJockeys,
      state.leagueTier,
      state.inventory,
      state.equippedEquipment,
      state.buildings,
      classIdx: state.currentClassIndex,
    );

    state = state.copyWith(
      gold: withGold ? state.gold - goldCost : state.gold,
      diamonds: withGold ? state.diamonds : state.diamonds - diamondCost,
      horses: newHorses,
      jockeys: newJockeys,
      winChance: newWinChance,
      lastSaved: DateTime.now(),
    );

    return {
      'isHorse': isHorseCard,
      'name': cardName,
      'tier': chestTier,
      'stars': stars,
    };
  }

  // 5-to-1 Merge Mechanics
  Map<String, dynamic>? mergeAsset(bool isHorse, int index) {
    if (isHorse) {
      final horse = state.horses[index];
      if (horse.duplicateCardCount >= 5) {
        final updatedHorse = horse.copyWith(
          duplicateCardCount: horse.duplicateCardCount - 5,
          currentStars: horse.currentStars + 1,
        );
        final newHorses = List<HorseAsset>.from(state.horses);
        newHorses[index] = updatedHorse;

        final double newWinChance = _calculateWinChance(
          newHorses,
          state.jockeys,
          state.leagueTier,
          state.inventory,
          state.equippedEquipment,
          state.buildings,
          classIdx: state.currentClassIndex,
        );

        state = state.copyWith(
          horses: newHorses,
          winChance: newWinChance,
          lastSaved: DateTime.now(),
        );
        return {
          'isHorse': true,
          'name': horse.name,
          'stars': updatedHorse.currentStars,
        };
      }
    } else {
      final jockey = state.jockeys[index];
      if (jockey.duplicateCardCount >= 5) {
        final updatedJockey = jockey.copyWith(
          duplicateCardCount: jockey.duplicateCardCount - 5,
          currentStars: jockey.currentStars + 1,
        );
        final newJockeys = List<JockeyAsset>.from(state.jockeys);
        newJockeys[index] = updatedJockey;

        final double newWinChance = _calculateWinChance(
          state.horses,
          newJockeys,
          state.leagueTier,
          state.inventory,
          state.equippedEquipment,
          state.buildings,
          classIdx: state.currentClassIndex,
        );

        state = state.copyWith(
          jockeys: newJockeys,
          winChance: newWinChance,
          lastSaved: DateTime.now(),
        );
        return {
          'isHorse': false,
          'name': jockey.name,
          'stars': updatedJockey.currentStars,
        };
      }
    }
    return null;
  }

  // Keep compatibility for older equipment chest openings
  bool openChestWithGold() {
    final double cost = 1000.0 * math.pow(10.0, state.leagueTier);
    if (state.gold >= cost) {
      final newItem = _generateRandomEquipment();
      final newInventory = List<EquipmentItem>.from(state.inventory)..add(newItem);

      state = state.copyWith(
        gold: state.gold - cost,
        inventory: newInventory,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  bool openChestWithDiamonds() {
    const int cost = 3;
    if (state.diamonds >= cost) {
      final newItem = _generateRandomEquipment();
      final newInventory = List<EquipmentItem>.from(state.inventory)..add(newItem);

      state = state.copyWith(
        diamonds: state.diamonds - cost,
        inventory: newInventory,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  EquipmentItem _generateRandomEquipment() {
    final random = math.Random();
    final double roll = random.nextDouble();
    
    String rarity;
    double winChanceBonus;
    if (roll < 0.50) {
      rarity = 'common';
      winChanceBonus = 0.02;
    } else if (roll < 0.80) {
      rarity = 'rare';
      winChanceBonus = 0.05;
    } else if (roll < 0.95) {
      rarity = 'epic';
      winChanceBonus = 0.09;
    } else {
      rarity = 'legendary';
      winChanceBonus = 0.15;
    }

    final types = ['horseshoe', 'whip', 'saddle'];
    final String type = types[random.nextInt(types.length)];

    String name;
    if (type == 'horseshoe') {
      if (rarity == 'common') {
        name = 'Rusty Horseshoe';
      } else if (rarity == 'rare') {
        name = 'Steel Horseshoe';
      } else if (rarity == 'epic') {
        name = 'Golden Horseshoe';
      } else {
        name = 'Lucky Horseshoe';
      }
    } else if (type == 'whip') {
      if (rarity == 'common') {
        name = 'Basic Whip';
      } else if (rarity == 'rare') {
        name = 'Jockey Whip';
      } else if (rarity == 'epic') {
        name = 'Master Whip';
      } else {
        name = 'Sonic Whip';
      }
    } else {
      if (rarity == 'common') {
        name = 'Old Saddle';
      } else if (rarity == 'rare') {
        name = 'Leather Saddle';
      } else if (rarity == 'epic') {
        name = 'Feather Saddle';
      } else {
        name = 'Imperial Saddle';
      }
    }

    final String uniqueId = 'eq_${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1000)}';

    return EquipmentItem(
      id: uniqueId,
      name: name,
      type: type,
      rarity: rarity,
      winChanceBonus: winChanceBonus,
    );
  }

  void equipItem(String itemId) {
    final itemIndex = state.inventory.indexWhere((e) => e.id == itemId);
    if (itemIndex == -1) return;

    final item = state.inventory[itemIndex];
    final type = item.type;

    final newEquipped = Map<String, String>.from(state.equippedEquipment);
    newEquipped[type] = itemId;

    final double newWinChance = _calculateWinChance(
      state.horses,
      state.jockeys,
      state.leagueTier,
      state.inventory,
      newEquipped,
      state.buildings,
      classIdx: state.currentClassIndex,
    );

    state = state.copyWith(
      equippedEquipment: newEquipped,
      winChance: newWinChance,
      lastSaved: DateTime.now(),
    );
  }

  void unequipItem(String type) {
    if (!state.equippedEquipment.containsKey(type)) return;

    final newEquipped = Map<String, String>.from(state.equippedEquipment);
    newEquipped.remove(type);

    final double newWinChance = _calculateWinChance(
      state.horses,
      state.jockeys,
      state.leagueTier,
      state.inventory,
      newEquipped,
      state.buildings,
      classIdx: state.currentClassIndex,
    );

    state = state.copyWith(
      equippedEquipment: newEquipped,
      winChance: newWinChance,
      lastSaved: DateTime.now(),
    );
  }

  bool buyInstaWin() {
    if (state.diamonds >= 2) {
      double goldEarned = 100.0 * math.pow(10.0, state.leagueTier);
      double pointsEarned = 30.0;

      double finalPoints = state.leaguePoints + pointsEarned;
      int finalTier = state.leagueTier;
      String finalLeagueName = state.currentDerbyLeague;
      
      double nextWinChance = state.winChance;
      double nextGoldPerSecond = state.goldPerSecond;

      if (finalPoints >= 100.0) {
        if (finalTier < 5) {
          finalTier++;
          finalPoints = 0.0;
          finalLeagueName = getDerbyName(finalTier);
          nextWinChance = _calculateWinChance(
            state.horses,
            state.jockeys,
            finalTier,
            state.inventory,
            state.equippedEquipment,
            state.buildings,
            classIdx: 0,
          );
          nextGoldPerSecond = _calculateGoldPerSecond(state.buildings);
        } else {
          finalPoints = 100.0;
        }
      }

      final int count = _raceHorseCount(state.currentClassIndex);
      final nextRanks = _rollRaceRanks(nextWinChance, math.Random(), count: count);

      state = state.copyWith(
        gold: state.gold + goldEarned,
        diamonds: state.diamonds - 2,
        currentDerbyLeague: finalLeagueName,
        leagueTier: finalTier,
        leaguePoints: finalPoints,
        winChance: nextWinChance,
        goldPerSecond: nextGoldPerSecond,
        horsePositions: List.filled(count, 0.0),
        raceRanks: nextRanks,
        raceTimeLeft: 45,
        raceDurationSeconds: 45,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  bool buySponsorVIP() {
    final bool hasVip = state.equippedEquipment['vip_pass'] == 'active';
    if (!hasVip && state.diamonds >= 5) {
      final newEquipped = Map<String, String>.from(state.equippedEquipment);
      newEquipped['vip_pass'] = 'active';
      state = state.copyWith(
        diamonds: state.diamonds - 5,
        equippedEquipment: newEquipped,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  bool tradeGoldForDiamonds() {
    double cost = 150.0 * math.pow(10.0, state.leagueTier);
    if (state.gold >= cost) {
      state = state.copyWith(
        gold: state.gold - cost,
        diamonds: state.diamonds + 1,
        lastSaved: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  double _calculateWinChance(
    List<HorseAsset> horses,
    List<JockeyAsset> jockeys,
    int tier,
    List<EquipmentItem> inventory,
    Map<String, String> equipped,
    Map<String, int> buildings, {
    int classIdx = 0,
  }) {
    if (tier >= horses.length || tier >= jockeys.length) {
      return 0.20;
    }
    final activeHorse = horses[tier];
    final activeJockey = jockeys[tier];

    // Calculate Stable Level Stats (sum of all stats and skills for the active tier)
    int stableLevelStats = 0;
    activeHorse.stats.forEach((key, level) {
      if (key == 'speed' || key == 'stamina') {
        stableLevelStats += level * 3;
      } else {
        stableLevelStats += level * 2;
      }
    });
    activeJockey.skills.forEach((key, level) {
      if (key == 'pacing') {
        stableLevelStats += level * 3;
      } else {
        stableLevelStats += level * 2;
      }
    });

    // Calculate Total Power
    int totalPower = stableLevelStats + (activeHorse.currentStars * 100) + (activeJockey.currentStars * 100);

    // Calculate Division Base Difficulty
    final difficulties = [800.0, 3600.0, 21600.0, 147600.0, 1254600.0];
    double baseDifficulty = difficulties[classIdx.clamp(0, difficulties.length - 1)];
    double divisionBaseDifficulty = baseDifficulty * math.pow(4.0, tier);

    // Calculate base win chance using the diminishing returns formula
    double baseWinChance = totalPower / (totalPower + divisionBaseDifficulty);

    // Calculate equipment contribution
    double equipmentBonus = 0.0;
    equipped.forEach((slot, itemId) {
      final itemIndex = inventory.indexWhere((e) => e.id == itemId);
      if (itemIndex != -1) {
        equipmentBonus += inventory[itemIndex].winChanceBonus;
      }
    });

    double winChance = baseWinChance + equipmentBonus;
    return winChance.clamp(0.01, 0.99);
  }

  double _calculateGoldPerSecond(Map<String, int> buildings) {
    double total = 0.0;
    final trackLevel = buildings['training_track'] ?? 0;
    final medicalLevel = buildings['medical_center'] ?? 0;
    final storageLevel = buildings['feed_storage'] ?? 0;
    final labLevel = buildings['research_lab'] ?? 0;
    final stableLevel = buildings['luxury_stable'] ?? 0;

    total += trackLevel * 1.0;
    total += medicalLevel * 3.0;
    total += storageLevel * 6.0;
    total += labLevel * 12.0;
    total += stableLevel * 24.0;

    return total;
  }

  GameStateModel _applyOfflineProgress(GameStateModel currentState, DateTime now) {
    final difference = now.difference(currentState.lastSaved);
    int secondsOffline = difference.inSeconds;
    if (secondsOffline > 7200 || secondsOffline < 0) {
      secondsOffline = 0;
    }

    if (currentState.goldPerSecond == 0) {
      return currentState.copyWith(
        pendingOfflineGold: 0.0,
        offlineDurationSeconds: secondsOffline,
        lastSaved: now,
      );
    }

    final bool hasVip = currentState.equippedEquipment['vip_pass'] == 'active';
    final double vipMultiplier = hasVip ? 2.0 : 1.0;
    final double passiveGoldSec = currentState.goldPerSecond * math.pow(10.0, currentState.leagueTier) * vipMultiplier;
    
    double offlineGoldEarned = 0.0;
    if (secondsOffline >= 60) {
      offlineGoldEarned = passiveGoldSec * secondsOffline;
    }

    int seasonsToSimulate = 0;
    if (secondsOffline >= 7200) {
      seasonsToSimulate = 2;
    } else if (secondsOffline >= 3600) {
      seasonsToSimulate = 1;
    }

    if (seasonsToSimulate > 0) {
      Map<String, dynamic> activeMap = {
        'currentClassIndex': currentState.currentClassIndex,
        'currentSeasonRace': currentState.currentSeasonRace,
        'seasonPoints': currentState.seasonPoints,
        'rivalSeasonPoints': currentState.rivalSeasonPoints,
        'recentPlacements': currentState.recentPlacements,
        'horsePositions': currentState.horsePositions,
        'raceTimeLeft': currentState.raceTimeLeft,
        'raceState': currentState.raceState,
        'raceRanks': currentState.raceRanks,
        'currentRaceRivalNames': currentState.currentRaceRivalNames,
        'rivalJockeyNames': currentState.rivalJockeyNames,
        'playerGateNumber': currentState.playerGateNumber,
        'winChance': currentState.winChance,
        'resultsCountdown': currentState.resultsCountdown,
        'lastRacePlacement': currentState.lastRacePlacement,
        'lastRaceGoldEarned': currentState.lastRaceGoldEarned,
        'lastRacePointsEarned': currentState.lastRacePointsEarned,
        'season': currentState.season,
        'seasonHistory': currentState.seasonHistory,
        'seasonClassHistory': currentState.seasonClassHistory,
        'buildings': currentState.buildings,
      };

      for (int s = 0; s < seasonsToSimulate; s++) {
        for (int tier = 0; tier <= currentState.unlockedLeagueTier; tier++) {
          final bool isCurrent = (tier == currentState.leagueTier);
          
          if (!isCurrent && !_leagueStates.containsKey(tier)) {
            _initializeLeagueState(tier, currentState);
          }
          
          final Map<String, dynamic> targetMap = isCurrent
              ? activeMap
              : Map<String, dynamic>.from(_leagueStates[tier]!);
          final int classIdx = targetMap['currentClassIndex'] as int? ?? 0;
          final int matchCap = _matchCapForClass(classIdx);
          
          for (int m = 0; m < matchCap; m++) {
            offlineGoldEarned += _simulateBackgroundMatch(tier, targetMap, currentState);
          }
          
          if (isCurrent) {
            activeMap = targetMap;
          } else {
            _leagueStates[tier] = targetMap;
          }
        }
      }

      currentState = currentState.copyWith(
        currentClassIndex: activeMap['currentClassIndex'] as int,
        currentSeasonRace: activeMap['currentSeasonRace'] as int,
        seasonPoints: activeMap['seasonPoints'] as double,
        rivalSeasonPoints: (activeMap['rivalSeasonPoints'] as List).cast<double>(),
        recentPlacements: (activeMap['recentPlacements'] as List).cast<int>(),
        horsePositions: (activeMap['horsePositions'] as List).cast<double>(),
        raceTimeLeft: activeMap['raceTimeLeft'] as int,
        raceState: activeMap['raceState'] as String,
        raceRanks: (activeMap['raceRanks'] as List).cast<int>(),
        currentRaceRivalNames: (activeMap['currentRaceRivalNames'] as List).cast<String>(),
        rivalJockeyNames: (activeMap['rivalJockeyNames'] as List).cast<String>(),
        playerGateNumber: activeMap['playerGateNumber'] as int,
        winChance: activeMap['winChance'] as double,
        resultsCountdown: activeMap['resultsCountdown'] as int,
        lastRacePlacement: activeMap['lastRacePlacement'] as int,
        lastRaceGoldEarned: activeMap['lastRaceGoldEarned'] as double,
        lastRacePointsEarned: activeMap['lastRacePointsEarned'] as double,
        season: activeMap['season'] as int,
        seasonHistory: (activeMap['seasonHistory'] as List).cast<int>(),
        seasonClassHistory: (activeMap['seasonClassHistory'] as List).cast<String>(),
        buildings: (activeMap['buildings'] as Map).cast<String, int>(),
      );
    }

    return currentState.copyWith(
      gold: currentState.gold + offlineGoldEarned,
      pendingOfflineGold: offlineGoldEarned,
      offlineDurationSeconds: secondsOffline,
      lastSaved: now,
    );
  }

  void simulateOfflineProgress(Duration duration) {
    final simulatedPastSaveTime = DateTime.now().subtract(duration);
    final stateBeforeOffline = state.copyWith(lastSaved: simulatedPastSaveTime);
    state = _applyOfflineProgress(stateBeforeOffline, DateTime.now());
  }

  void resetGame() {
    sharedPrefs.setInt('active_league_tier', 0);
    sharedPrefs.setInt('active_class_index', 0);
    sharedPrefs.setInt('unlocked_league_tier', 0);
    sharedPrefs.remove('game_state_json');
    sharedPrefs.remove('league_states_json');
    _leagueStates.clear();
    final freshHorses = GameStateModel.defaultHorses();
    final freshJockeys = GameStateModel.defaultJockeys();
    // Force tier=0, classIdx=0 → 200 / (200 + 800) = 20%
    final freshWinChance = _calculateWinChance(
      freshHorses, freshJockeys,
      0, const [], const {},
      const {
        'training_track': 0, 'medical_center': 0,
        'feed_storage': 0, 'research_lab': 0, 'luxury_stable': 0,
      },
      classIdx: 0,
    );
    final int cnt = _raceHorseCount(0);
    final rand = math.Random();
    final newRivals = _pickRaceRivalNames(rand, count: cnt - 1);
    final initialRanks = _rollRaceRanks(freshWinChance, rand, count: cnt);

    state = GameStateModel.initial().copyWith(
      winChance: freshWinChance,
      leagueTier: 0,
      currentClassIndex: 0,
      unlockedLeagueTier: 0,
      horsePositions: List.filled(cnt, 0.0),
      raceTimeLeft: 450,
      raceDurationSeconds: 45,
      raceState: 'racing',
      playerGateNumber: rand.nextInt(cnt),
      currentRaceRivalNames: newRivals,
      rivalJockeyNames: newRivals,
      raceRanks: initialRanks,
      seasonPoints: 0.0,
      rivalSeasonPoints: List.filled(cnt - 1, 0.0),
      currentSeasonRace: 1,
      recentPlacements: const [],
      resultsCountdown: 0,
    );
  }

  void _saveLeagueState(int tier) {
    _leagueStates[tier] = {
      'currentClassIndex': state.currentClassIndex,
      'currentSeasonRace': state.currentSeasonRace,
      'seasonPoints': state.seasonPoints,
      'rivalSeasonPoints': state.rivalSeasonPoints,
      'recentPlacements': state.recentPlacements,
      'horsePositions': state.horsePositions,
      'raceTimeLeft': state.raceTimeLeft,
      'raceState': state.raceState,
      'raceRanks': state.raceRanks,
      'currentRaceRivalNames': state.currentRaceRivalNames,
      'rivalJockeyNames': state.rivalJockeyNames,
      'playerGateNumber': state.playerGateNumber,
      'winChance': state.winChance,
      'resultsCountdown': state.resultsCountdown,
      'lastRacePlacement': state.lastRacePlacement,
      'lastRaceGoldEarned': state.lastRaceGoldEarned,
      'lastRacePointsEarned': state.lastRacePointsEarned,
      'season': state.season,
      'seasonHistory': state.seasonHistory,
      'seasonClassHistory': state.seasonClassHistory,
      'buildings': state.buildings,
    };
  }

  void _initializeLeagueState(int tier, GameStateModel currentGameState) {
    final double newWinChance = _calculateWinChance(
      currentGameState.horses,
      currentGameState.jockeys,
      tier,
      currentGameState.inventory,
      currentGameState.equippedEquipment,
      const {
        'training_track': 0,
        'medical_center': 0,
        'feed_storage': 0,
        'research_lab': 0,
        'luxury_stable': 0,
      },
      classIdx: 0,
    );
    final int cnt = _raceHorseCount(0);
    final nextRanks = _rollRaceRanks(newWinChance, math.Random(), count: cnt);
    final newRivals = _pickRaceRivalNames(math.Random(), count: cnt - 1);
    
    _leagueStates[tier] = {
      'currentClassIndex': 0,
      'currentSeasonRace': 1,
      'seasonPoints': 0.0,
      'rivalSeasonPoints': List.filled(cnt - 1, 0.0),
      'recentPlacements': <int>[],
      'horsePositions': List.filled(cnt, 0.0),
      'raceTimeLeft': 450,
      'raceState': 'racing',
      'raceRanks': nextRanks,
      'currentRaceRivalNames': newRivals,
      'rivalJockeyNames': newRivals,
      'playerGateNumber': math.Random().nextInt(cnt),
      'winChance': newWinChance,
      'resultsCountdown': 0,
      'lastRacePlacement': 1,
      'lastRaceGoldEarned': 0.0,
      'lastRacePointsEarned': 0.0,
      'season': 1,
      'seasonHistory': <int>[],
      'seasonClassHistory': <String>[],
      'buildings': const {
        'training_track': 0,
        'medical_center': 0,
        'feed_storage': 0,
        'research_lab': 0,
        'luxury_stable': 0,
      },
      'bgTicks': 0,
    };
  }

  double _simulateBackgroundMatch(
    int tier,
    Map<String, dynamic> leagueState,
    GameStateModel currentGameState,
  ) {
    final rand = math.Random();
    final double winChance = leagueState['winChance'] as double;
    final int classIdx = leagueState['currentClassIndex'] as int;
    final int cnt = _raceHorseCount(classIdx);
    
    // 1. Simulate placement
    final double roll = rand.nextDouble() * 100.0;
    final bool canWin1st = !(winChance > 0.0 && winChance < 0.20);
    int playerRank = 1;
    if (!canWin1st || roll >= winChance * 100.0) {
      playerRank = rand.nextInt(cnt - 1) + 2;
    }
    
    // 2. Points
    double pointsForRank(int rank) {
      if (rank == 1) return 30.0;
      if (rank == 2) return 15.0;
      if (rank == 3) return 5.0;
      return 0.0;
    }
    
    double playerPointsEarned = pointsForRank(playerRank);
    double currentPoints = (leagueState['seasonPoints'] as num).toDouble() + playerPointsEarned;
    leagueState['seasonPoints'] = currentPoints;
    
    final List<double> rivalPoints = List<double>.from((leagueState['rivalSeasonPoints'] as List).cast<double>());
    for (int i = 0; i < rivalPoints.length; i++) {
      int rivalRank = rand.nextInt(cnt) + 1;
      while (rivalRank == playerRank) {
        rivalRank = rand.nextInt(cnt) + 1;
      }
      rivalPoints[i] += pointsForRank(rivalRank);
    }
    leagueState['rivalSeasonPoints'] = rivalPoints;
    
    double baseGold = 100.0;
    if (playerRank == 1) {
      baseGold = 500.0;
    } else if (playerRank == 2) {
      baseGold = 400.0;
    } else if (playerRank == 3) {
      baseGold = 300.0;
    } else if (playerRank == 4) {
      baseGold = 200.0;
    }
    
    final bool hasVip = currentGameState.equippedEquipment['vip_pass'] == 'active';
    final double vipMultiplier = hasVip ? 2.0 : 1.0;
    final double boostMultiplier = currentGameState.boostTimeLeft > 0 ? 2.0 : 1.0;
    double goldEarned = baseGold * math.pow(10.0, tier) * vipMultiplier * boostMultiplier;
    
    final List<int> recent = List<int>.from((leagueState['recentPlacements'] as List? ?? []).cast<int>());
    recent.insert(0, playerRank);
    if (recent.length > 5) recent.removeLast();
    leagueState['recentPlacements'] = recent;
    
    // 4. Update match index
    int currentSeasonRaceNum = leagueState['currentSeasonRace'] as int;
    final int matchCap = _matchCapForClass(classIdx);
    
    if (currentSeasonRaceNum < matchCap) {
      leagueState['currentSeasonRace'] = currentSeasonRaceNum + 1;
    } else {
      // Genuinely finished season
      final int finalRank = rivalPoints.where((rp) => rp > currentPoints).length + 1;
      final bool isPlayerFirst = rivalPoints.every((rp) => currentPoints >= rp);
      
      final int oldSeason = leagueState['season'] as int? ?? 1;
      leagueState['season'] = oldSeason + 1;
      
      final List<int> seasonHistory = List<int>.from((leagueState['seasonHistory'] as List? ?? []).cast<int>())..add(finalRank);
      if (seasonHistory.length > 10) seasonHistory.removeAt(0);
      leagueState['seasonHistory'] = seasonHistory;
      
      final List<String> seasonClassHistory = List<String>.from((leagueState['seasonClassHistory'] as List? ?? []).cast<String>())
        ..add('$tier,$classIdx');
      if (seasonClassHistory.length > 10) seasonClassHistory.removeAt(0);
      leagueState['seasonClassHistory'] = seasonClassHistory;
      
      int nextClassIndex = classIdx;
      if (isPlayerFirst && !(tier == 5 && classIdx == 4)) {
        if (nextClassIndex < 4) {
          nextClassIndex++;
        }
      }
      
      final double newWinChance = _calculateWinChance(
        currentGameState.horses,
        currentGameState.jockeys,
        tier,
        currentGameState.inventory,
        currentGameState.equippedEquipment,
        (leagueState['buildings'] as Map?)?.cast<String, int>() ?? const {
          'training_track': 0,
          'medical_center': 0,
          'feed_storage': 0,
          'research_lab': 0,
          'luxury_stable': 0,
        },
        classIdx: nextClassIndex,
      );
      
      final int nextHorseCount = _raceHorseCount(nextClassIndex);
      final newRivals = _pickRaceRivalNames(rand, count: nextHorseCount - 1);
      final nextRanksPerm = _rollRaceRanks(newWinChance, rand, count: nextHorseCount);
      
      leagueState['currentClassIndex'] = nextClassIndex;
      leagueState['seasonPoints'] = 0.0;
      leagueState['rivalSeasonPoints'] = List.filled(nextHorseCount - 1, 0.0);
      leagueState['currentRaceRivalNames'] = newRivals;
      leagueState['rivalJockeyNames'] = newRivals;
      leagueState['currentSeasonRace'] = 1;
      leagueState['horsePositions'] = List.filled(nextHorseCount, 0.0);
      leagueState['raceRanks'] = nextRanksPerm;
      leagueState['winChance'] = newWinChance;
    }
    
    return goldEarned;
  }

  void debugChangeClass(bool increase) {
    int nextClassIndex = state.currentClassIndex;
    int nextLeagueTier = state.leagueTier;
    
    if (increase) {
      if (nextClassIndex < 4) {
        nextClassIndex++;
      } else {
        if (nextLeagueTier < 5) {
          nextLeagueTier++;
          nextClassIndex = 0;
        }
      }
    } else {
      if (nextClassIndex > 0) {
        nextClassIndex--;
      } else {
        if (nextLeagueTier > 0) {
          nextLeagueTier--;
          nextClassIndex = 4;
        }
      }
    }

    final String nextLeagueName = getDerbyName(nextLeagueTier);
    final double newWinChance = _calculateWinChance(
      state.horses,
      state.jockeys,
      nextLeagueTier,
      state.inventory,
      state.equippedEquipment,
      state.buildings,
      classIdx: nextClassIndex,
    );

    final int count = _raceHorseCount(nextClassIndex);
    final newRivals = _pickRaceRivalNames(math.Random(), count: count - 1);
    final nextRanks = _rollRaceRanks(newWinChance, math.Random(), count: count);

    _finishedHorses.clear();

    state = state.copyWith(
      currentClassIndex: nextClassIndex,
      leagueTier: nextLeagueTier,
      currentDerbyLeague: nextLeagueName,
      winChance: newWinChance,
      unlockedLeagueTier: math.max(state.unlockedLeagueTier, nextLeagueTier),
      seasonPoints: 0.0,
      rivalSeasonPoints: List.filled(count - 1, 0.0),
      rivalJockeyNames: newRivals,
      currentRaceRivalNames: newRivals,
      currentSeasonRace: 1,
      raceState: 'racing',
      raceTimeLeft: 450,
      horsePositions: List.filled(count, 0.0),
      raceRanks: nextRanks,
      lastSaved: DateTime.now(),
    );
  }

  void debugAddGold(double amount) {
    double newGold = (state.gold + amount).clamp(0.0, double.infinity);
    state = state.copyWith(
      gold: newGold,
      lastSaved: DateTime.now(),
    );
  }

  // ─── Yardımcı: Yarış için rastgele rakip at ismi seç ───
  static List<String> _pickRaceRivalNames(math.Random random, {int count = 4}) {
    final pool = <String>[
      'Thunderbolt', 'Silver Arrow', 'Desert Storm', 'Night Fury',
      'Golden Flash', 'Iron Duke', 'Crimson Tide', 'Wild Wind',
      'Black Diamond', 'Royal Flush', 'Storm Chase', 'Wild Card',
      'Lucky Strike', 'Blazing Star', 'Celtic Fire', 'Midnight Run',
      'Falcon Ridge', 'Shadow Dance', 'Prairie Wind', 'Steel Force',
      'Arctic Blast', 'Fire Dragon', 'Ocean Wave', 'Canyon King',
      'Phantom Ride', 'Eagle Eye', 'Copper Crown', 'Amber Flame',
      'Blue Bolt', 'Ruby Quest', 'Jade Spirit', 'Silk Road',
      'River Bend', 'Mountain Peak', 'Sunrise Glory', 'Stardust',
      'Noble Quest', 'Titan Force', 'Silver Ghost', 'Rapid Flash',
      'Thunder King', 'Windy Blaze', 'Storm Rider', 'Desert Wind',
      'Brave Heart', 'Swift Arrow', 'Iron Will', 'Golden Dream',
    ];
    pool.shuffle(random);
    return pool.take(count).toList();
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameStateModel>(() {
  return GameNotifier();
});
