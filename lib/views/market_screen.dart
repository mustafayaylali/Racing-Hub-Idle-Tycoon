import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/game_controller.dart';
import '../theme/app_theme.dart';
import '../localization/locale_provider.dart';
import '../models/game_state_model.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  Timer? _timer;
  bool _adLoading = false;

  @override
  void initState() {
    super.initState();
    // Refresh countdown timer every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatNumber(double number) {
    if (number >= 1e12) return '${(number / 1e12).toStringAsFixed(1)}t';
    if (number >= 1e9) return '${(number / 1e9).toStringAsFixed(1)}b';
    if (number >= 1e6) return '${(number / 1e6).toStringAsFixed(1)}m';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}k';
    return number.toStringAsFixed(0);
  }

  void _watchAdForNormalBox(BuildContext context, GameNotifier notifier, String locale) {
    setState(() {
      _adLoading = true;
    });

    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.mintGreen),
                const SizedBox(height: 16),
                Text(
                  locale == 'tr' ? 'Reklam İzleniyor...' : 'Watching Ad...',
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (nav.canPop()) {
        nav.pop();
      }
      
      final result = notifier.openNormalBoxAd();
      
      setState(() {
        _adLoading = false;
      });

      if (result != null) {
        final gameState = ref.read(gameProvider);
        if (context.mounted) {
          _showMarketBoxResultDialog(context, result, locale, gameState);
        }
      } else {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(locale == 'tr' ? '❌ Günlük limit doldu!' : '❌ Daily limit reached!'),
            backgroundColor: AppTheme.salmonPink,
          ),
        );
      }
    });
  }

  double roundDownToTensUnit(double value) {
    if (value <= 10.0) return value.floorToDouble();
    double factor = 10.0;
    while (factor * 10.0 <= value) {
      factor *= 10.0;
    }
    return (value / factor).floorToDouble() * factor;
  }

  void _watchAdForDiamonds(BuildContext context, GameNotifier notifier, String locale) {
    setState(() {
      _adLoading = true;
    });

    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.mintGreen),
                const SizedBox(height: 16),
                Text(
                  locale == 'tr' ? 'Reklam İzleniyor...' : 'Watching Ad...',
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (nav.canPop()) {
        nav.pop();
      }
      
      final currentAdCount = notifier.getDiamondAdCounter();
      notifier.watchAdForDiamonds();
      
      setState(() {
        _adLoading = false;
      });

      if (currentAdCount + 1 >= 3) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(locale == 'tr' 
                ? '🎉 3/3 Reklam izlendi! 10 Elmas kazanıldı!' 
                : '🎉 3/3 Ads watched! 10 Diamonds earned!'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      } else {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(locale == 'tr' 
                ? 'Reklam izlendi (${currentAdCount + 1}/3)' 
                : 'Ad watched (${currentAdCount + 1}/3)'),
            backgroundColor: AppTheme.mintGreen,
          ),
        );
      }
    });
  }

  Widget _buildDiamondAdBundle(BuildContext context, GameNotifier notifier, String locale) {
    final adCount = notifier.getDiamondAdCounter();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📺', style: TextStyle(fontSize: 16)),
              SizedBox(width: 4),
              Text(
                '💎 10',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1976D2)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _adLoading
                ? null
                : () => _watchAdForDiamonds(context, notifier, locale),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mintGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: const Size.fromHeight(26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill, size: 10),
                const SizedBox(width: 2),
                Text(
                  '$adCount/3',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinPack(
    BuildContext context,
    GameNotifier notifier,
    int packIndex,
    double coinsAmount,
    int diamondCost,
    String emoji,
    String locale,
    GameStateModel gameState,
  ) {
    final bool canAfford = gameState.diamonds >= diamondCost;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatNumber(coinsAmount),
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFD68F1A)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: canAfford
                  ? () {
                      final success = notifier.buyCoinsWithDiamonds(coinsAmount, diamondCost);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(locale == 'tr'
                                ? '🎉 Satın alma başarılı! ${_formatNumber(coinsAmount)} Coin eklendi.'
                                : '🎉 Purchase successful! ${_formatNumber(coinsAmount)} Coins added.'),
                            backgroundColor: AppTheme.mintGreen,
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size.fromHeight(26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                '💎 $diamondCost',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketAdPack(BuildContext context, GameNotifier notifier, String locale) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade100, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎫', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  locale == 'tr' ? '1 Bilet' : '1 Ticket',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.charcoalBrown),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _adLoading
                  ? null
                  : () {
                      setState(() {
                        _adLoading = true;
                      });
                      final nav = Navigator.of(context);
                      final scaffold = ScaffoldMessenger.of(context);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => Dialog(
                          backgroundColor: AppTheme.creamBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(color: AppTheme.mintGreen),
                                const SizedBox(height: 16),
                                Text(
                                  locale == 'tr' ? 'Reklam İzleniyor...' : 'Watching Ad...',
                                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      Future.delayed(const Duration(seconds: 2), () {
                        if (!mounted) return;
                        if (nav.canPop()) nav.pop();
                        notifier.claimAdTicket();
                        setState(() {
                          _adLoading = false;
                        });
                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text(locale == 'tr' ? '🎉 1 Giriş Bileti Kazanıldı!' : '🎉 1 Entrance Ticket Claimed!'),
                            backgroundColor: AppTheme.mintGreen,
                          ),
                        );
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size.fromHeight(26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill, size: 10),
                  const SizedBox(width: 2),
                  Text(locale == 'tr' ? 'Reklam' : 'Ad', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketPurchasePack(
    BuildContext context,
    GameNotifier notifier,
    int amount,
    int diamondCost,
    String locale,
    GameStateModel gameState,
  ) {
    final bool canAfford = gameState.diamonds >= diamondCost;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.shade100, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎫', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  locale == 'tr' ? '$amount Bilet' : '$amount Tickets',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.charcoalBrown),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: canAfford
                  ? () {
                      final success = notifier.buyTicketWithDiamonds(diamondCost, amount);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(locale == 'tr'
                                ? '🎉 Satın alma başarılı! $amount Bilet eklendi.'
                                : '🎉 Purchase successful! $amount Tickets added.'),
                            backgroundColor: AppTheme.mintGreen,
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size.fromHeight(26),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                '💎 $diamondCost',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarketBoxResultDialog(BuildContext context, Map<String, dynamic> result, String locale, GameStateModel gameState) {
    final int tier = result['tier'] as int;
    final String name = result['name'] as String;
    final int amount = result['amount'] as int;
    final double stars = 1.5 + tier * 0.5;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFFF1EADF), width: 2),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  locale == 'tr' ? 'Kutudan Çıkanlar' : 'Chest Unboxed',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.mintGreen.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        CategoryConfig.categories[gameState.leagueTier].asset1Emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoalBrown,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: List.generate(5, (index) {
                                final double starLimit = index + 1.0;
                                if (stars >= starLimit) {
                                  return const Icon(Icons.star_rounded, color: Colors.amber, size: 10);
                                } else if (stars > starLimit - 1.0) {
                                  return const Icon(Icons.star_half_rounded, color: Colors.amber, size: 10);
                                } else {
                                  return const Icon(Icons.star_outline_rounded, color: Colors.grey, size: 10);
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.mintGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+$amount ${locale == 'tr' ? 'Parça' : 'Frags'}',
                          style: const TextStyle(
                            color: AppTheme.mintGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(locale == 'tr' ? 'Harika' : 'Excellent'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);
    final locale = ref.watch(localeProvider);

    final double cCurrent = gameState.gold;
    final double pack1Coins = math.max(100.0, (cCurrent / 8.0).floorToDouble());
    final double pack2Coins = math.max(500.0, roundDownToTensUnit(cCurrent / 2.0));
    final double pack3Coins = math.max(1000.0, roundDownToTensUnit(cCurrent));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          locale == 'tr' ? 'Market & Mağaza' : 'Market & Shop',
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ─── Pinned Global Currency Counters (Premium Top HUD) ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(bottom: BorderSide(color: Color(0xFFF1EADF), width: 1.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gold counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.creamBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        _formatNumber(gameState.gold),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFFD68F1A),
                        ),
                      ),
                    ],
                  ),
                ),
                // Diamond counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.creamBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        gameState.diamonds.toString(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                ),
                // Ticket counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.creamBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade300, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Text('🎫', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        gameState.tickets.toString(),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

              Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 📦 Fragment Boxes Section
                Text(
                  locale == 'tr' ? '📦 Fragment Kutuları' : '📦 Fragment Boxes',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Normal Kutu (Ad-supported)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Text('📦', style: TextStyle(fontSize: 32)),
                            const SizedBox(height: 6),
                            Text(
                              locale == 'tr' ? 'Normal Kutu' : 'Normal Box',
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locale == 'tr' ? 'Sonraki Seviye Parçası' : 'Next Tier Fragment',
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, color: AppTheme.mutedBrown),
                            ),
                            const SizedBox(height: 4),
                            // Daily counter 0/3
                            Text(
                              '${notifier.getNormalBoxAdCounter()}/3',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: notifier.getNormalBoxAdCounter() >= 3 ? AppTheme.salmonPink : AppTheme.mintGreen,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: notifier.getNormalBoxAdCounter() < 3 && !_adLoading
                                  ? () => _watchAdForNormalBox(context, notifier, locale)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.mintGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: const Size.fromHeight(30),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_circle_outline_rounded, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    locale == 'tr' ? 'Reklam İzle' : 'Watch Ad',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Altın Kutu (Premium)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.shade200, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            const Text('🎁', style: TextStyle(fontSize: 32)),
                            const SizedBox(height: 6),
                            Text(
                              locale == 'tr' ? 'Altın Kutu' : 'Gold Box',
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locale == 'tr' ? 'Rastgele Üst Parçalar' : 'Random Tier Frags',
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, color: AppTheme.mutedBrown),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '30 💎',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: gameState.diamonds >= 30
                                  ? () {
                                      final result = notifier.openGoldBoxPremium();
                                      if (result != null) {
                                        _showMarketBoxResultDialog(context, result, locale, gameState);
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gameState.diamonds >= 30 ? Colors.amber : Colors.grey.shade300,
                                foregroundColor: gameState.diamonds >= 30 ? Colors.white : AppTheme.mutedBrown,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: const Size.fromHeight(30),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                locale == 'tr' ? 'Aç' : 'Open',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
 
                // 💎 Premium Diamond Bundles
                Text(
                  locale == 'tr' ? '💎 Premium Elmas Mağazası' : '💎 Premium Diamond Shop',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                  children: [
                    _buildDiamondAdBundle(context, notifier, locale),
                    _buildDiamondBundle(context, notifier, 100, '\$0.99', '✨', locale),
                    _buildDiamondBundle(context, notifier, 255, '\$1.99', '🪙', locale),
                    _buildDiamondBundle(context, notifier, 520, '\$4.99', '💰', locale),
                    _buildDiamondBundle(context, notifier, 1100, '\$9.99', '👑', locale),
                    _buildDiamondBundle(context, notifier, 2750, '\$19.99', '🏆', locale),
                  ],
                ),
                const SizedBox(height: 20),

                // 🪙 Coin Al Section
                Text(
                  locale == 'tr' ? '🪙 Coin Al' : '🪙 Buy Coins',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildCoinPack(context, notifier, 1, pack1Coins, 10, '🪙', locale, gameState),
                    const SizedBox(width: 8),
                    _buildCoinPack(context, notifier, 2, pack2Coins, 30, '💰', locale, gameState),
                    const SizedBox(width: 8),
                    _buildCoinPack(context, notifier, 3, pack3Coins, 50, '🏆', locale, gameState),
                  ],
                ),
                const SizedBox(height: 20),

                // 🎫 Bilet Mağazası Section
                Text(
                  locale == 'tr' ? '🎫 Bilet Mağazası' : '🎫 Ticket Shop',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTicketAdPack(context, notifier, locale),
                    const SizedBox(width: 8),
                    _buildTicketPurchasePack(context, notifier, 1, 10, locale, gameState),
                    const SizedBox(width: 8),
                    _buildTicketPurchasePack(context, notifier, 5, 45, locale, gameState),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiamondBundle(BuildContext context, GameNotifier notifier, int diamonds, String price, String emoji, String locale) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '💎 $diamonds',
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1976D2)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              notifier.buyDiamondsBundle(diamonds);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(locale == 'tr'
                      ? '🎉 Satın alma başarılı! $diamonds Elmas eklendi.'
                      : '🎉 Purchase successful! $diamonds Diamonds added.'),
                  backgroundColor: AppTheme.mintGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: const Size.fromHeight(26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(price, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
