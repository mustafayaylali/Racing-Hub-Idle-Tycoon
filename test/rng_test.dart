import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

List<int> rollRaceRanks(double winChance, math.Random random) {
  final ranks = List<int>.filled(5, 0);
  final roll = random.nextDouble() * 100.0;
  if (roll < winChance * 100.0) {
    ranks[0] = 1;
    final otherRanks = [2, 3, 4, 5];
    otherRanks.shuffle(random);
    for (int i = 1; i < 5; i++) {
      ranks[i] = otherRanks[i - 1];
    }
  } else {
    final winnerRivalIndex = random.nextInt(4) + 1;
    ranks[winnerRivalIndex] = 1;
    final playerRank = random.nextInt(4) + 2;
    ranks[0] = playerRank;
    final remainingRanks = [2, 3, 4, 5];
    remainingRanks.remove(playerRank);
    remainingRanks.shuffle(random);
    int remIdx = 0;
    for (int i = 1; i < 5; i++) {
      if (i != winnerRivalIndex) {
        ranks[i] = remainingRanks[remIdx++];
      }
    }
  }
  return ranks;
}

void main() {
  test('RNG Win Chance & Non-Winning Decoupling Simulation', () {
    final random = math.Random(12345);
    const double winChance = 0.05;
    const int iterations = 100000;
    
    int wins = 0;
    final Map<int, int> nonWinningDistribution = {2: 0, 3: 0, 4: 0, 5: 0};

    for (int i = 0; i < iterations; i++) {
      final ranks = rollRaceRanks(winChance, random);
      final playerRank = ranks[0];
      if (playerRank == 1) {
        wins++;
      } else {
        nonWinningDistribution[playerRank] = nonWinningDistribution[playerRank]! + 1;
      }
    }

    final double winRate = wins / iterations;
    
    // Win rate should be very close to 5% (0.05)
    expect(winRate, closeTo(0.05, 0.005));

    // Distribution should be roughly uniform among 2nd, 3rd, 4th, 5th
    final expectedNonWinsPerSlot = (iterations * (1 - winChance)) / 4;
    nonWinningDistribution.forEach((rank, count) {
      expect(count.toDouble(), closeTo(expectedNonWinsPerSlot, expectedNonWinsPerSlot * 0.05));
    });
  });
}
