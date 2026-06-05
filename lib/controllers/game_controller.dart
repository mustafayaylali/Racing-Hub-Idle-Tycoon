import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import '../models/game_state_model.dart';
import '../main.dart';


class GameNotifier extends Notifier<GameStateModel> {
  Timer? _gameLoopTimer;
  int _tickCount = 0;
  final List<int> _finishedHorses = [];
  final Map<int, Map<String, dynamic>> _leagueStates = {};

  DateTime _initialTrustedTime = DateTime.now();
  final Stopwatch _sessionStopwatch = Stopwatch();
  bool _isTimeTrusted = false;

  bool get isTimeTrusted => _isTimeTrusted;

  DateTime get _currentTrustedTime {
    return _initialTrustedTime.add(_sessionStopwatch.elapsed);
  }

  Future<void> _fetchNetworkTime() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('https://clients3.google.com/generate_204'));
      final response = await request.close();
      final dateHeader = response.headers.value('date');
      if (dateHeader != null) {
        final parsedNetworkTime = HttpDate.parse(dateHeader);
        final localTime = DateTime.now();
        final diff = parsedNetworkTime.difference(localTime).inSeconds.abs();
        
        _initialTrustedTime = parsedNetworkTime;
        _sessionStopwatch.reset();
        _sessionStopwatch.start();
        
        if (diff > 60) {
          _isTimeTrusted = false;
          debugPrint("WARNING: Device clock is altered by $diff seconds! Network time used instead.");
        } else {
          _isTimeTrusted = true;
        }
      }
    } catch (e) {
      _isTimeTrusted = false;
    }
  }


  String _calculateChecksum(String data) {
    const String salt = "RacingHubPrivateSaltKey2026!";
    final bytes = utf8.encode(data + salt);
    return sha256.convert(bytes).toString();
  }

  String _encrypt(String input) {
    const String salt = "RacingHubPrivateSaltKey2026!";
    final List<int> inputBytes = utf8.encode(input);
    final List<int> keyBytes = utf8.encode(salt);
    final List<int> resultBytes = List<int>.filled(inputBytes.length, 0);
    for (int i = 0; i < inputBytes.length; i++) {
      resultBytes[i] = inputBytes[i] ^ keyBytes[i % keyBytes.length] ^ (i * 31 % 256);
    }
    return base64.encode(resultBytes);
  }

  String _decrypt(String base64Input) {
    const String salt = "RacingHubPrivateSaltKey2026!";
    final List<int> inputBytes = base64.decode(base64Input);
    final List<int> keyBytes = utf8.encode(salt);
    final List<int> resultBytes = List<int>.filled(inputBytes.length, 0);
    for (int i = 0; i < inputBytes.length; i++) {
      resultBytes[i] = inputBytes[i] ^ keyBytes[i % keyBytes.length] ^ (i * 31 % 256);
    }
    return utf8.decode(resultBytes);
  }


  List<Map<String, dynamic>> getDisciplineRanks() {
    final List<Map<String, dynamic>> ranks = [];
    for (int tier = 0; tier < CategoryConfig.categories.length; tier++) {
      double seasonPoints = 0.0;
      List<double> rivalSeasonPoints = [];
      int classIndex = 0;

      if (tier == state.leagueTier) {
        seasonPoints = state.seasonPoints;
        rivalSeasonPoints = state.rivalSeasonPoints;
        classIndex = state.currentClassIndex;
      } else {
        final saved = _leagueStates[tier];
        if (saved != null) {
          seasonPoints = (saved['seasonPoints'] as num?)?.toDouble() ?? 0.0;
          rivalSeasonPoints = (saved['rivalSeasonPoints'] as List?)?.cast<double>() ?? const [];
          classIndex = saved['currentClassIndex'] as int? ?? 0;
        } else {
          seasonPoints = 0.0;
          rivalSeasonPoints = const [];
          classIndex = 0;
        }
      }

      int rank = 1;
      if (rivalSeasonPoints.isNotEmpty) {
        rank = rivalSeasonPoints.where((rp) => rp > seasonPoints).length + 1;
      }

      ranks.add({
        'tier': tier,
        'nameTr': CategoryConfig.categories[tier].nameTr,
        'nameEn': CategoryConfig.categories[tier].nameEn,
        'emoji': CategoryConfig.categories[tier].asset1Emoji,
        'rank': rank,
        'points': seasonPoints,
        'classIndex': classIndex,
      });
    }
    return ranks;
  }

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
    int relativeLevel = math.max(0, level - 1);
    return baseGold * _getLeagueModifier(tier) * math.pow(1.15, relativeLevel);
  }

  double getJockeySkillUpgradeCost(int tier, int level, String skillId) {
    double baseGold = (skillId == 'pacing') ? 300.0 : 200.0;
    return baseGold * _getLeagueModifier(tier) * math.pow(1.15, level);
  }

  String getDerbyName(int tier) {
    if (tier >= 0 && tier < CategoryConfig.categories.length) {
      return CategoryConfig.categories[tier].nameTr;
    }
    return '🛥️ Deniz Yarışı';
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
    final now = _currentTrustedTime;
    if (shouldSaveNow || _lastDiskSaveTime == null || now.difference(_lastDiskSaveTime!) > const Duration(seconds: 5)) {
      _lastDiskSaveTime = now;
      sharedPrefs.setString('last_saved_time', value.lastSaved.toIso8601String());
      
      final jsonStr = jsonEncode(value.toJson());
      final checksum = _calculateChecksum(jsonStr);
      final envelope = {
        'data': jsonStr,
        'checksum': checksum,
      };
      final encryptedState = _encrypt(jsonEncode(envelope));
      sharedPrefs.setString('game_state_json', encryptedState);
      
      final Map<String, Map<String, dynamic>> serialized = _leagueStates.map(
        (key, val) => MapEntry(key.toString(), val),
      );
      final encryptedLeagues = _encrypt(jsonEncode(serialized));
      sharedPrefs.setString('league_states_json', encryptedLeagues);
    }
    
    super.state = value;
  }

  @override
  GameStateModel build() {
    _initialTrustedTime = DateTime.now();
    _sessionStopwatch.reset();
    _sessionStopwatch.start();
    _fetchNetworkTime();

    _startGameLoop();

    final now = _currentTrustedTime;

    // 1. Load league states first
    final String? leagueStatesStr = sharedPrefs.getString('league_states_json');
    if (leagueStatesStr != null) {
      try {
        final String decrypted = leagueStatesStr.startsWith('{') ? leagueStatesStr : _decrypt(leagueStatesStr);
        final decoded = jsonDecode(decrypted) as Map<String, dynamic>;
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
        final String decrypted = gameStateJson.startsWith('{') ? gameStateJson : _decrypt(gameStateJson);
        final decoded = jsonDecode(decrypted) as Map<String, dynamic>;
        GameStateModel loadedState;
        if (decoded.containsKey('data') && decoded.containsKey('checksum')) {
          final String dataStr = decoded['data'] as String;
          final String expectedChecksum = decoded['checksum'] as String;
          final String actualChecksum = _calculateChecksum(dataStr);
          if (actualChecksum == expectedChecksum) {
            final Map<String, dynamic> stateJson = jsonDecode(dataStr) as Map<String, dynamic>;
            loadedState = GameStateModel.fromJson(stateJson);
          } else {
            throw Exception("Checksum mismatch - save data tampered!");
          }
        } else {
          // older format fallback
          loadedState = GameStateModel.fromJson(decoded);
        }
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
      tickets: 2,
      lastTicketClaimTime: DateTime.fromMillisecondsSinceEpoch(0),
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
    final bool canWin1st = winChance > 0.25;
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
    final now = _currentTrustedTime;
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


  /// Çevrimdışı kazancı toplar. [doubled] = true ise reklam izlenerek 2 katı alınır.
  void collectOfflineGold({bool doubled = false}) {
    if (doubled) {
      state = state.copyWith(
        gold: state.gold + state.pendingOfflineGold,
        pendingOfflineGold: 0.0,
        offlineDurationSeconds: 0,
        lastSaved: _currentTrustedTime,
      );
    } else {
      state = state.copyWith(
        pendingOfflineGold: 0.0,
        offlineDurationSeconds: 0,
        lastSaved: _currentTrustedTime,
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
        lastSaved: _currentTrustedTime,
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
      lastSaved: _currentTrustedTime,
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
      lastSaved: _currentTrustedTime,
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
        lastSaved: _currentTrustedTime,
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
    if (horse.currentStars == 0.0) {
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
        lastSaved: _currentTrustedTime,
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
        lastSaved: _currentTrustedTime,
      );
      return true;
    }
    return false;
  }

  void _updateWinChance() {
    final double newWinChance = _calculateWinChance(
      state.horses,
      state.jockeys,
      state.leagueTier,
      state.inventory,
      state.equippedEquipment,
      state.buildings,
      classIdx: state.currentClassIndex,
    );
    state = state.copyWith(winChance: newWinChance);
  }

  bool buyPremiumHorse(int tier) {
    if (tier < 0 || tier >= state.horses.length) return false;
    final cost = (tier + 1) * 30;
    if (state.diamonds >= cost) {
      final oldHorse = state.horses[tier];
      if (oldHorse.currentStars > 0) return false; // Already unlocked

      final double starValue = tier == 7 ? 5.0 : 1.0 + tier * 0.5;
      final newHorse = oldHorse.copyWith(
        currentStars: starValue,
      );

      final newHorses = List<HorseAsset>.from(state.horses);
      newHorses[tier] = newHorse;

      state = state.copyWith(
        diamonds: state.diamonds - cost,
        horses: newHorses,
        lastSaved: _currentTrustedTime,
      );
      _updateWinChance();
      return true;
    }
    return false;
  }

  int getNextNeededHorseTier() {
    for (int i = 0; i < state.horses.length; i++) {
      if (state.horses[i].currentStars == 0.0) {
        return i;
      }
    }
    return state.horses.length - 1;
  }

  void addHorseFragments(int tier, int amount) {
    if (tier < 0 || tier >= state.horses.length) return;
    final oldHorse = state.horses[tier];
    int newFragments = oldHorse.duplicateCardCount + amount;
    double newStars = oldHorse.currentStars;
    
    if (newStars == 0.0 && newFragments >= 20) {
      newStars = tier == 7 ? 5.0 : 1.0 + tier * 0.5; // Unlock the horse AVD tier!
    }
    
    final newHorse = oldHorse.copyWith(
      duplicateCardCount: newFragments,
      currentStars: newStars,
    );
    
    final newHorses = List<HorseAsset>.from(state.horses);
    newHorses[tier] = newHorse;
    
    state = state.copyWith(
      horses: newHorses,
      lastSaved: _currentTrustedTime,
    );
    _updateWinChance();
  }

  int getNormalBoxAdCounter() {
    return sharedPrefs.getInt('normal_box_ad_count') ?? 0;
  }

  void resetNormalBoxAdCounter() {
    sharedPrefs.setInt('normal_box_ad_count', 0);
  }

  Map<String, dynamic>? openNormalBoxAd() {
    final currentCount = getNormalBoxAdCounter();
    if (currentCount >= 3) return null;

    final nextCount = currentCount + 1;
    sharedPrefs.setInt('normal_box_ad_count', nextCount);

    final nextTier = getNextNeededHorseTier();
    addHorseFragments(nextTier, 1);

    return {
      'type': 'horse',
      'tier': nextTier,
      'amount': 1,
      'name': state.horses[nextTier].name,
      'counter': nextCount,
    };
  }

  Map<String, dynamic>? openGoldBoxPremium() {
    const cost = 30; // 30 Diamonds
    if (state.diamonds >= cost) {
      state = state.copyWith(diamonds: state.diamonds - cost);
      
      final rand = math.Random();
      final roll = rand.nextInt(100);
      
      final currentNeededTier = getNextNeededHorseTier();
      int selectedOffset = 0;
      
      if (roll < 5) {
        selectedOffset = 4;
      } else if (roll < 15) {
        selectedOffset = 3;
      } else if (roll < 30) {
        selectedOffset = 2;
      } else if (roll < 50) {
        selectedOffset = 1;
      } else {
        selectedOffset = 0;
      }
      
      int targetTier = currentNeededTier + selectedOffset;
      if (targetTier >= state.horses.length) {
        targetTier = state.horses.length - 1;
      }
      
      final amount = 3 + rand.nextInt(3); 
      addHorseFragments(targetTier, amount);
      
      return {
        'type': 'horse',
        'tier': targetTier,
        'amount': amount,
        'name': state.horses[targetTier].name,
      };
    }
    return null;
  }

  List<double> getStandardChestDropRates() {
    int tCurrent = state.unlockedLeagueTier; // 0 to 7
    List<double> weights = List.filled(8, 0.0);
    
    if (tCurrent >= 7) {
      return List.filled(8, 12.5);
    }
    
    int next1 = tCurrent + 1;
    int next2 = tCurrent + 2;
    int next3 = tCurrent + 3;
    
    List<int> farTiers = [];
    for (int i = tCurrent + 4; i <= tCurrent + 6; i++) {
      if (i < 7) farTiers.add(i);
    }
    
    int endgame = 7;
    
    double weightNext1 = 55.0;
    double weightNext2 = 25.0;
    double weightNext3 = 12.0;
    double weightFar = 7.5;
    double weightEndgame = 0.5;
    
    if (next1 <= 7) weights[next1] = weightNext1;
    if (next2 <= 7) weights[next2] = weightNext2;
    if (next3 <= 7) weights[next3] = weightNext3;
    
    if (farTiers.isNotEmpty) {
      double perFar = weightFar / farTiers.length;
      for (int t in farTiers) {
        weights[t] = perFar;
      }
    } else {
      if (next1 <= 7) weights[next1] += weightFar * 0.5;
      if (next2 <= 7) weights[next2] += weightFar * 0.5;
    }
    
    weights[endgame] = weightEndgame;
    
    final bool allUnlocked = state.horses.every((h) => h.currentStars > 0.0);
    if (!allUnlocked) {
      for (int i = 0; i < weights.length; i++) {
        if (state.horses[i].currentStars > 0.0) {
          weights[i] = 0.0;
        }
      }
    }
    
    double sum = weights.reduce((a, b) => a + b);
    if (sum > 0) {
      for (int i = 0; i < weights.length; i++) {
        weights[i] = (weights[i] / sum) * 100.0;
      }
    }
    return weights;
  }

  int rollStandardChestDrop(math.Random rand) {
    final rates = getStandardChestDropRates();
    double roll = rand.nextDouble() * 100.0;
    double cumulative = 0.0;
    for (int i = 0; i < rates.length; i++) {
      cumulative += rates[i];
      if (roll <= cumulative) {
        return i;
      }
    }
    return 7;
  }

  Map<String, dynamic>? openStandardChest1xTicket() {
    if (state.tickets >= 1) {
      state = state.copyWith(tickets: state.tickets - 1);
      final rand = math.Random();
      final tier = rollStandardChestDrop(rand);
      addHorseFragments(tier, 1);
      return {
        'type': 'horse',
        'tier': tier,
        'amount': 1,
        'name': state.horses[tier].name,
      };
    }
    return null;
  }

  List<Map<String, dynamic>>? openStandardChest10xDiamonds() {
    const cost = 100;
    if (state.diamonds >= cost) {
      state = state.copyWith(diamonds: state.diamonds - cost);
      final rand = math.Random();
      final List<Map<String, dynamic>> drops = [];
      final Map<int, int> tierDrops = {};
      for (int i = 0; i < 10; i++) {
        final tier = rollStandardChestDrop(rand);
        tierDrops[tier] = (tierDrops[tier] ?? 0) + 1;
      }
      tierDrops.forEach((tier, amount) {
        addHorseFragments(tier, amount);
        drops.add({
          'type': 'horse',
          'tier': tier,
          'amount': amount,
          'name': state.horses[tier].name,
        });
      });
      return drops;
    }
    return null;
  }

  List<double> getRareChestDropRates() {
    int tCurrent = state.unlockedLeagueTier; // 0 to 7
    List<double> weights = List.filled(8, 0.0);
    
    if (tCurrent >= 7) {
      return List.filled(8, 12.5);
    }
    
    int next1 = tCurrent + 1;
    int next2 = tCurrent + 2;
    
    List<int> midTiers = [];
    for (int i = tCurrent + 3; i <= tCurrent + 5; i++) {
      if (i < 7) midTiers.add(i);
    }
    
    List<int> highTiers = [];
    if (tCurrent + 6 < 7) {
      highTiers.add(tCurrent + 6);
    }
    
    int endgame = 7;
    
    double weightNext1 = 35.0;
    double weightNext2 = 30.0;
    double weightMid = 25.0;
    double weightHigh = 8.0;
    double weightEndgame = 2.0;
    
    if (next1 <= 7) weights[next1] = weightNext1;
    if (next2 <= 7) weights[next2] = weightNext2;
    
    if (midTiers.isNotEmpty) {
      double perMid = weightMid / midTiers.length;
      for (int t in midTiers) {
        weights[t] = perMid;
      }
    } else {
      if (next1 <= 7) weights[next1] += weightMid * 0.5;
      if (next2 <= 7) weights[next2] += weightMid * 0.5;
    }
    
    if (highTiers.isNotEmpty) {
      for (int t in highTiers) {
        weights[t] = weightHigh;
      }
    } else {
      if (next2 <= 7) weights[next2] += weightHigh;
    }
    
    weights[endgame] = weightEndgame;
    
    final bool allUnlocked = state.horses.every((h) => h.currentStars > 0.0);
    if (!allUnlocked) {
      for (int i = 0; i < weights.length; i++) {
        if (state.horses[i].currentStars > 0.0) {
          weights[i] = 0.0;
        }
      }
    }
    
    double sum = weights.reduce((a, b) => a + b);
    if (sum > 0) {
      for (int i = 0; i < weights.length; i++) {
        weights[i] = (weights[i] / sum) * 100.0;
      }
    }
    return weights;
  }

  int rollRareChestDrop(math.Random rand) {
    final rates = getRareChestDropRates();
    double roll = rand.nextDouble() * 100.0;
    double cumulative = 0.0;
    for (int i = 0; i < rates.length; i++) {
      cumulative += rates[i];
      if (roll <= cumulative) {
        return i;
      }
    }
    return 7;
  }

  Map<String, dynamic>? openNadirChest1xDiamonds() {
    const cost = 50;
    if (state.diamonds >= cost) {
      state = state.copyWith(diamonds: state.diamonds - cost);
      final rand = math.Random();
      final tier = rollRareChestDrop(rand);
      final amount = 3;
      addHorseFragments(tier, amount);
      return {
        'type': 'horse',
        'tier': tier,
        'amount': amount,
        'name': state.horses[tier].name,
      };
    }
    return null;
  }

  List<Map<String, dynamic>>? openNadirChest10xDiamonds() {
    const cost = 500;
    if (state.diamonds >= cost) {
      state = state.copyWith(diamonds: state.diamonds - cost);
      final rand = math.Random();
      final List<Map<String, dynamic>> drops = [];
      final Map<int, int> tierDrops = {};
      for (int i = 0; i < 10; i++) {
        final tier = rollRareChestDrop(rand);
        tierDrops[tier] = (tierDrops[tier] ?? 0) + 3;
      }
      tierDrops.forEach((tier, amount) {
        addHorseFragments(tier, amount);
        drops.add({
          'type': 'horse',
          'tier': tier,
          'amount': amount,
          'name': state.horses[tier].name,
        });
      });
      return drops;
    }
    return null;
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
        id: 'j_prem_${_currentTrustedTime.microsecondsSinceEpoch}',
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
        lastSaved: _currentTrustedTime,
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
      lastSaved: _currentTrustedTime,
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
      lastSaved: _currentTrustedTime,
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
        lastSaved: _currentTrustedTime,
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
    double stars = 1.0;

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
      lastSaved: _currentTrustedTime,
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
          currentStars: math.min(5.0, horse.currentStars + 0.5),
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
          lastSaved: _currentTrustedTime,
        );
        return {
          'isHorse': true,
          'name': horse.name,
          'stars': updatedHorse.currentStars,
          'tier': index,
        };
      }
    } else {
      final jockey = state.jockeys[index];
      if (jockey.duplicateCardCount >= 5) {
        final updatedJockey = jockey.copyWith(
          duplicateCardCount: jockey.duplicateCardCount - 5,
          currentStars: math.min(5.0, jockey.currentStars + 0.5),
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
          lastSaved: _currentTrustedTime,
        );
        return {
          'isHorse': false,
          'name': jockey.name,
          'stars': updatedJockey.currentStars,
          'tier': index,
        };
      }
    }
    return null;
  }

  Map<String, dynamic>? openChestWithTicket(int chestTier, bool isHorse) {
    if (state.tickets < 1) {
      return null;
    }

    String cardName = '';
    double stars = 1.0;

    List<HorseAsset> newHorses = List.from(state.horses);
    List<JockeyAsset> newJockeys = List.from(state.jockeys);

    if (isHorse) {
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
      tickets: state.tickets - 1,
      horses: newHorses,
      jockeys: newJockeys,
      winChance: newWinChance,
      lastSaved: _currentTrustedTime,
    );

    return {
      'isHorse': isHorse,
      'name': cardName,
      'tier': chestTier,
      'stars': stars,
    };
  }

  bool claimFreeTicket() {
    final now = _currentTrustedTime;
    final diff = now.difference(state.lastTicketClaimTime);
    if (diff >= const Duration(seconds: 30)) {
      state = state.copyWith(
        tickets: state.tickets + 1,
        lastTicketClaimTime: now,
        lastSaved: now,
      );
      return true;
    }
    return false;
  }

  void claimAdTicket() {
    state = state.copyWith(
      tickets: state.tickets + 1,
      lastSaved: _currentTrustedTime,
    );
  }

  void buyDiamondsBundle(int amount) {
    state = state.copyWith(
      diamonds: state.diamonds + amount,
      lastSaved: _currentTrustedTime,
    );
  }

  int getDiamondAdCounter() {
    return sharedPrefs.getInt('diamond_ad_count') ?? 0;
  }

  void watchAdForDiamonds() {
    final currentCount = getDiamondAdCounter();
    int nextCount = currentCount + 1;
    if (nextCount >= 3) {
      state = state.copyWith(
        diamonds: state.diamonds + 10,
        lastSaved: _currentTrustedTime,
      );
      nextCount = 0;
    }
    sharedPrefs.setInt('diamond_ad_count', nextCount);
  }

  bool buyCoinsWithDiamonds(double amount, int cost) {
    if (state.diamonds >= cost) {
      state = state.copyWith(
        diamonds: state.diamonds - cost,
        gold: state.gold + amount,
        lastSaved: _currentTrustedTime,
      );
      return true;
    }
    return false;
  }

  bool buyTicketWithDiamonds(int cost, int amount) {
    if (state.diamonds >= cost) {
      state = state.copyWith(
        diamonds: state.diamonds - cost,
        tickets: state.tickets + amount,
        lastSaved: _currentTrustedTime,
      );
      return true;
    }
    return false;
  }

  bool buyCardPack(bool isGold) {
    if (isGold) {
      const double cost = 5000.0;
      if (state.gold >= cost) {
        List<HorseAsset> newHorses = List.from(state.horses);
        List<JockeyAsset> newJockeys = List.from(state.jockeys);
        final random = math.Random();
        for (int i = 0; i < 5; i++) {
          final isHorseCard = random.nextBool();
          final int tier = random.nextInt(state.leagueTier + 1);
          if (isHorseCard) {
            final horse = state.horses[tier];
            newHorses[tier] = horse.copyWith(
              duplicateCardCount: horse.duplicateCardCount + 1,
            );
          } else {
            final jockey = state.jockeys[tier];
            newJockeys[tier] = jockey.copyWith(
              duplicateCardCount: jockey.duplicateCardCount + 1,
            );
          }
        }
        state = state.copyWith(
          gold: state.gold - cost,
          horses: newHorses,
          jockeys: newJockeys,
          lastSaved: _currentTrustedTime,
        );
        return true;
      }
    } else {
      const int cost = 20;
      if (state.diamonds >= cost) {
        List<HorseAsset> newHorses = List.from(state.horses);
        List<JockeyAsset> newJockeys = List.from(state.jockeys);
        final random = math.Random();
        for (int i = 0; i < 5; i++) {
          final isHorseCard = random.nextBool();
          final int tier = random.nextInt(state.leagueTier + 1);
          if (isHorseCard) {
            final horse = state.horses[tier];
            newHorses[tier] = horse.copyWith(
              duplicateCardCount: horse.duplicateCardCount + 1,
            );
          } else {
            final jockey = state.jockeys[tier];
            newJockeys[tier] = jockey.copyWith(
              duplicateCardCount: jockey.duplicateCardCount + 1,
            );
          }
        }
        state = state.copyWith(
          diamonds: state.diamonds - cost,
          horses: newHorses,
          jockeys: newJockeys,
          lastSaved: _currentTrustedTime,
        );
        return true;
      }
    }
    return false;
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
        lastSaved: _currentTrustedTime,
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
        lastSaved: _currentTrustedTime,
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

    final String uniqueId = 'eq_${_currentTrustedTime.microsecondsSinceEpoch}_${random.nextInt(1000)}';

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
      lastSaved: _currentTrustedTime,
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
      lastSaved: _currentTrustedTime,
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
        lastSaved: _currentTrustedTime,
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
        lastSaved: _currentTrustedTime,
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
        lastSaved: _currentTrustedTime,
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

    int horseStatsSum = 0;
    activeHorse.stats.forEach((key, level) {
      int baseVal = 0;
      switch (key) {
        case 'speed': baseVal = 20; break;
        case 'stamina': baseVal = 20; break;
        case 'acceleration': baseVal = 15; break;
        case 'focus': baseVal = 15; break;
        case 'cornering': baseVal = 10; break;
        case 'temper': baseVal = 20; break;
      }
      horseStatsSum += baseVal + (level - 1) * 3;
    });

    int jockeySkillsSum = 0;
    activeJockey.skills.forEach((key, level) {
      if (key == 'pacing') {
        jockeySkillsSum += level * 3;
      } else {
        jockeySkillsSum += level * 2;
      }
    });

    // Calculate Total Power: (Horse Stats Sum + Horse Star Coefficient) + (Jockey Skills Sum + Jockey Star Coefficient)
    int horseTotalPower = horseStatsSum + (activeHorse.currentStars * 100).toInt();
    int jockeyTotalPower = jockeySkillsSum + (activeJockey.currentStars * 100).toInt();
    int totalPower = horseTotalPower + jockeyTotalPower;

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
    if (secondsOffline < 0) {
      secondsOffline = 0;
    } else if (secondsOffline > 7200) {
      secondsOffline = 7200; // Cap at 2 hours max
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
    final simulatedPastSaveTime = _currentTrustedTime.subtract(duration);
    final stateBeforeOffline = state.copyWith(lastSaved: simulatedPastSaveTime);
    state = _applyOfflineProgress(stateBeforeOffline, _currentTrustedTime);
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
    final bool canWin1st = winChance > 0.25;
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
      lastSaved: _currentTrustedTime,
    );
  }

  void debugAddGold(double amount) {
    double newGold = (state.gold + amount).clamp(0.0, double.infinity);
    state = state.copyWith(
      gold: newGold,
      lastSaved: _currentTrustedTime,
    );
  }

  void debugAddDiamonds(int amount) {
    int newDiamonds = (state.diamonds + amount).clamp(0, 999999999);
    state = state.copyWith(
      diamonds: newDiamonds,
      lastSaved: _currentTrustedTime,
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
