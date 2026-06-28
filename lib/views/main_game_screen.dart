import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/game_controller.dart';
import '../models/game_state_model.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';
import '../localization/locale_provider.dart';
import '../main.dart';
import '../services/audio_service.dart';
import 'market_screen.dart';

class MainGameScreen extends ConsumerStatefulWidget {
  const MainGameScreen({super.key});

  @override
  ConsumerState<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends ConsumerState<MainGameScreen> {
  final List<String> _commentaryLogs = [
    '🏁 Hipodrom hazır! Yarış yakında başlıyor...',
  ];
  bool _offlineDialogShown = false;
  int _selectedHorseIndex = 0;
  int _selectedJockeyIndex = 0;
  List<int>? _lastTickHorseOrder;
  int? _lastTabIndex;
  late final ScrollController _horseScrollController = ScrollController();

  // Lig renkleri (dinamik pist arka planı)
  static const List<List<Color>> _leagueTrackGradients = [
    [Color(0xFF1B3B22), Color(0xFF0F2414)], // Koyu Orman Yeşili (Category 1)
    [Color(0xFF388E3C), Color(0xFF1B5E20)], // Şehir - çim yeşili
    [Color(0xFF4E342E), Color(0xFF2C1A0E)], // Bölgesel - koyu toprak
    [Color(0xFFB8860B), Color(0xFF7A5C00)], // Ulusal - altın kum
    [Color(0xFF2E7D32), Color(0xFF004D1A)], // Elit - premium turf
    [Color(0xFF1A237E), Color(0xFF0D1547)], // Efsanevi - kraliyet mavisi
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameState = ref.read(gameProvider);
      if (gameState.offlineDurationSeconds > 0 && !_offlineDialogShown) {
        _offlineDialogShown = true;
        _showOfflineEarningsDialog(gameState.pendingOfflineGold);
      }
      final locale = ref.read(localeProvider);
      setState(() {
        _commentaryLogs.clear();
        _commentaryLogs.add(AppStrings.get(locale, 'commentary_ready'));
      });
    });
  }

  @override
  void dispose() {
    _horseScrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveHorse(GameStateModel gameState) {
    if (_horseScrollController.hasClients) {
      final activeHorse = gameState.horses[gameState.leagueTier];
      final activeIndex = activeHorse.associatedLeagueTier;
      final double maxScroll = _horseScrollController.position.maxScrollExtent;
      final double target = (activeIndex * 113.0 - 12.0).clamp(0.0, maxScroll);
      _horseScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _addCommentary(String text) {
    setState(() {
      _commentaryLogs.insert(0, text);
      if (_commentaryLogs.length > 8) {
        _commentaryLogs.removeLast();
      }
    });
  }


  String _getClassName(int classIdx, String locale) {
    final classesTr = ["Yerel Amatör Kupası", "Bölgesel Profesyonel Lig", "Ulusal Grand Prix", "Kıtasal Şampiyona", "Dünya Şampiyonlar Derbisi"];
    final classesEn = ["Local Amateur Cup", "Regional Professional League", "National Grand Prix", "Continental Championship", "World Champions Derby"];
    final clampedIdx = classIdx.clamp(0, 4);
    return locale == 'tr' ? classesTr[clampedIdx] : classesEn[clampedIdx];
  }

  void _showGlobalScoreboardDialog(GameStateModel gameState) {
    final locale = ref.read(localeProvider);
    final notifier = ref.read(gameProvider.notifier);
    final disciplines = notifier.getDisciplineRanks();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF141416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE5A93C), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      locale == 'tr' ? '🏆 Küresel Skorlar' : '🏆 Global Leaderboard',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: disciplines.map((disc) {
                        final int rank = disc['rank'] as int;
                        final double points = disc['points'] as double;
                        final int classIdx = disc['classIndex'] as int;
                        final String classStr = _getClassName(classIdx, locale);

                        Widget rankWidget;
                        if (rank == 1) {
                          rankWidget = const Text('🥇', style: TextStyle(fontSize: 20));
                        } else if (rank == 2) {
                          rankWidget = const Text('🥈', style: TextStyle(fontSize: 20));
                        } else if (rank == 3) {
                          rankWidget = const Text('🥉', style: TextStyle(fontSize: 20));
                        } else {
                          rankWidget = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$rank',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          );
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E22),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                disc['emoji'] as String,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locale == 'tr' ? disc['nameTr'] as String : disc['nameEn'] as String,
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      classStr,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 10.5,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  rankWidget,
                                  const SizedBox(height: 4),
                                  Text(
                                    '${points.toStringAsFixed(0)} pts',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6EC6A1),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLeagueDialog(GameStateModel gameState, GameNotifier notifier) {
    final locale = ref.read(localeProvider);
    final leagueNames = CategoryConfig.categories
        .map((c) => locale == 'tr' ? c.nameTr : c.nameEn)
        .toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  locale == 'tr' ? '🏟️ Lig Seçimi' : '🏟️ League Selection',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(6, (i) {
                  final bool isUnlocked = i <= gameState.unlockedLeagueTier;
                  final bool isActive = i == gameState.leagueTier;
                  final bool isNextUnlock = i == gameState.unlockedLeagueTier + 1;
                  final double unlockCost = notifier.getLeagueUnlockCost(i);
                  final bool isAffordable = gameState.gold >= unlockCost;
                  final bool isClickable = isUnlocked || (isNextUnlock && isAffordable);

                  return GestureDetector(
                    onTap: isClickable
                        ? () {
                            Navigator.pop(ctx);
                            if (isUnlocked) {
                              notifier.setActiveLeague(i);
                            } else if (isNextUnlock && isAffordable) {
                              notifier.unlockNextLeague();
                            }
                          }
                        : null,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.mintGreen.withValues(alpha: 0.15)
                            : (isUnlocked
                                ? Colors.white
                                : (isNextUnlock
                                    ? const Color(0xFFFAF6EE)
                                    : const Color(0xFFE8E3D9))),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive
                              ? AppTheme.mintGreen
                              : (isNextUnlock
                                  ? const Color(0xFFE5A93C).withValues(alpha: 0.5)
                                  : Colors.transparent),
                          width: 2,
                        ),
                      ),
                      child: Opacity(
                        opacity: (isUnlocked || isNextUnlock) ? 1.0 : 0.45,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                leagueNames[i],
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  color: isUnlocked ? AppTheme.charcoalBrown : AppTheme.mutedBrown,
                                ),
                              ),
                            ),
                            if (isActive)
                              Text(
                                locale == 'tr' ? '✓ Aktif' : '✓ Active',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.mintGreen,
                                ),
                              )
                            else if (!isUnlocked && isNextUnlock)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isAffordable ? AppTheme.mintGreen : const Color(0xFFEFE8DE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '🪙${_formatNumber(unlockCost)}',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isAffordable ? Colors.white : AppTheme.mutedBrown,
                                  ),
                                ),
                              )
                            else if (!isUnlocked)
                              const Icon(Icons.lock_rounded, size: 14, color: AppTheme.mutedBrown),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(locale == 'tr' ? 'Kapat' : 'Close', style: const TextStyle(color: AppTheme.mutedBrown)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPromotionDialog(int newTier, String leagueName) {
    final locale = ref.read(localeProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: const BorderSide(color: Color(0xFFF1EADF), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.get(locale, 'promotion_title'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFEFE8DE), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppStrings.get(locale, 'promoted_to'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: AppTheme.mutedBrown,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        leagueName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.mintGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tier ${newTier + 1}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.salmonPink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.get(locale, 'promotion_note'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: AppTheme.mutedBrown,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  ),
                  child: Text(AppStrings.get(locale, 'continue_btn')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSponsorAdDialog(GameNotifier notifier) {
    final gameState = ref.read(gameProvider);
    final locale = ref.read(localeProvider);
    final bool isMega = gameState.sponsorIsMega;
    final double rewardGold = notifier.getSponsorRewardGold();
    final String formattedReward = AppStrings.formatGold(rewardGold);

    final String title = isMega
        ? (locale == 'tr' ? '🌟 MEGA SPONSOR TEKLİFİ! 🌟' : '🌟 MEGA SPONSOR OFFER! 🌟')
        : (locale == 'tr' ? '🎁 Sponsor Teklifi!' : '🎁 Sponsor Offer!');
    final String message = isMega
        ? (locale == 'tr'
            ? 'Şanslı günündesin! Bir VIP Mega Sponsor sana muazzam bir destek paketi teklif ediyor (10 Dk Altın veya 5 Elmas)!'
            : 'Lucky day! A VIP Mega Sponsor offers you a massive boost package (10m Gold or 5 Diamonds)!')
        : (locale == 'tr'
            ? 'Bir premium sponsor size özel bir altın desteği vermek istiyor! Bu ödülü almak için kısa bir video izleyin.'
            : 'A premium sponsor wants to grant you a special gold boost! Watch a short video to claim this reward.');
    final String claimBtnText = locale == 'tr' ? 'İzle & Al' : 'Watch & Claim';
    final String cancelBtnText = locale == 'tr' ? 'Teklifi Reddet' : 'Decline Offer';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: AppTheme.mutedBrown,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 8),
                    Text(
                      formattedReward,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.softAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          notifier.rejectSponsorReward();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEFE8DE)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          cancelBtnText,
                          style: const TextStyle(color: AppTheme.mutedBrown, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCountdownAdDialog(
                            title: title,
                            onComplete: () {
                              notifier.claimSponsorReward();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppStrings.get(locale, 'sponsor_claimed')),
                                  backgroundColor: AppTheme.mintGreen,
                                ),
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.softAmber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          claimBtnText,
                          style: const TextStyle(
                            color: AppTheme.charcoalBrown,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  void _showOfflineEarningsDialog(double earnings) {
    final gameState = ref.read(gameProvider);
    final durationSeconds = gameState.offlineDurationSeconds;
    if (durationSeconds <= 0) {
      return;
    }
    final locale = ref.read(localeProvider);
    final notifier = ref.read(gameProvider.notifier);

    final int hours = durationSeconds ~/ 3600;
    final int minutes = (durationSeconds % 3600) ~/ 60;
    final double progress = (durationSeconds / 7200.0).clamp(0.0, 1.0);

    final String durationText = locale == 'tr'
        ? 'Süre: $hours sa $minutes dk'
        : 'Duration: ${hours}h ${minutes}m';
    final String maxText = locale == 'tr' ? 'Maks: 2 saat' : 'Max: 2 hours';

    final bool isZeroIncome = gameState.goldPerSecond == 0;
    final bool isTooShort = durationSeconds < 60 && !isZeroIncome;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: const BorderSide(color: Color(0xFFF1EADF), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.get(locale, 'welcome_back_title'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEFE8DE), width: 1.5),
                  ),
                  child: isZeroIncome
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            locale == 'tr'
                                ? 'Tesisleriniz henüz gelir üretmediği için çevrimdışı kazanç elde edilemedi.'
                                : 'No offline earnings because facilities have not generated income yet.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.charcoalBrown,
                            ),
                          ),
                        )
                      : (isTooShort
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                locale == 'tr'
                                    ? 'Çevrimdışı kaldığın süre çok kısa olduğu için altın kazanılamadı.'
                                    : 'No offline gold earned because the offline duration was too short.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.charcoalBrown,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                Text(
                                  AppStrings.get(locale, 'offline_earned_label'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    color: AppTheme.mutedBrown,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🪙', style: TextStyle(fontSize: 24)),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppStrings.formatGold(earnings),
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.mintGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _AnimatedOfflineProgressBar(
                                  progress: progress,
                                  durationText: durationText,
                                  maxText: maxText,
                                ),
                              ],
                            )),
                ),
                const SizedBox(height: 20),
                if (isTooShort || isZeroIncome)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        notifier.collectOfflineGold(doubled: false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mintGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        locale == 'tr' ? 'Tamam' : 'OK',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            notifier.collectOfflineGold(doubled: false);
                            _spawnGoldParticles(earnings);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEFE8DE)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            AppStrings.get(locale, 'collect_btn'),
                            style: const TextStyle(color: AppTheme.mutedBrown),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCountdownAdDialog(
                              title: AppStrings.get(locale, 'welcome_back_title'),
                              onComplete: () {
                                notifier.collectOfflineGold(doubled: true);
                                _spawnGoldParticles(earnings * 2);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppStrings.get(locale, 'doubled_msg')),
                                    backgroundColor: AppTheme.mintGreen,
                                  ),
                                );
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.softAmber,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            AppStrings.get(locale, 'double_ad_btn'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.charcoalBrown,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }



  void _showCountdownAdDialog({
    required String title,
    required VoidCallback onComplete,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return CountdownAdDialog(
          title: title,
          onComplete: onComplete,
        );
      },
    );
  }

  void _spawnGoldParticles(double amount) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _GoldParticleOverlay(
        amount: amount,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  int _getSkillValue(String id, int level) {
    int baseVal = 0;
    switch (id) {
      case 'reflex': baseVal = 10; break;
      case 'balance': baseVal = 10; break;
      case 'tactics': baseVal = 8; break;
      case 'control': baseVal = 8; break;
      case 'condition': baseVal = 8; break;
      case 'motivation': baseVal = 6; break;
    }
    return baseVal + (level - 1) * 3;
  }

  int _getStarBonus(double stars) {
    if (stars == 6.0) return 10000;
    if (stars == 5.0) return 6000;
    if (stars == 4.0) return 2000;
    if (stars == 3.0) return 650;
    if (stars == 2.0) return 225;
    return 0;
  }

  int _getJockeyPower(JockeyAsset jockey) {
    int jockeySkillsSum = 0;
    jockey.skills.forEach((key, level) {
      jockeySkillsSum += _getSkillValue(key, level);
    });
    return jockeySkillsSum + _getStarBonus(jockey.currentStars);
  }

  Widget _buildStarRow(double currentStars, {double size = 12}) {
    if (currentStars == 6.0) {
      return Text(
        'VIP',
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFD700), // Gold
          letterSpacing: 1.0,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < currentStars.floor()) {
          return Icon(
            Icons.star_rounded,
            color: Colors.amber,
            size: size,
          );
        } else if (i == currentStars.floor() && (currentStars - currentStars.floor()) >= 0.5) {
          return Icon(
            Icons.star_half_rounded,
            color: Colors.amber,
            size: size,
          );
        } else {
          return Icon(
            Icons.star_rounded,
            color: Colors.grey.withValues(alpha: 0.3),
            size: size,
          );
        }
      }),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Consumer(
              builder: (context, ref, child) {
                final locale = ref.watch(localeProvider);
                final soundEnabled = ref.watch(soundEnabledProvider);
                final musicEnabled = ref.watch(musicEnabledProvider);
                final vibrateEnabled = ref.watch(vibrateEnabledProvider);

                Widget buildSettingRow({
                  required String label,
                  required String valueText,
                  required bool isActive,
                  required VoidCallback onTap,
                }) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoalBrown,
                          ),
                        ),
                        InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.mintGreen : AppTheme.mutedBrown.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive ? AppTheme.mintGreen : Colors.black12,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              valueText,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.white : AppTheme.charcoalBrown.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.get(locale, 'settings_title'),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoalBrown,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Colors.black12),
                    const SizedBox(height: 16),

                    // Dil Seçeneği (Dropdown)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.get(locale, 'settings_lang_label'),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoalBrown,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black12,
                                width: 1.5,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: locale,
                                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.charcoalBrown),
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoalBrown,
                                ),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    ref.read(localeProvider.notifier).state = newValue;
                                    sharedPrefs.setString('locale', newValue);
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(value: 'tr', child: Text('🇹🇷 Türkçe')),
                                  DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
                                  DropdownMenuItem(value: 'es', child: Text('🇪🇸 Español')),
                                  DropdownMenuItem(value: 'pt', child: Text('🇧🇷 Português')),
                                  DropdownMenuItem(value: 'ru', child: Text('🇷🇺 Русский')),
                                  DropdownMenuItem(value: 'de', child: Text('🇩🇪 Deutsch')),
                                  DropdownMenuItem(value: 'fr', child: Text('🇫🇷 Français')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Ses Seçeneği
                    buildSettingRow(
                      label: AppStrings.get(locale, 'settings_sound'),
                      valueText: soundEnabled ? AppStrings.get(locale, 'settings_on') : AppStrings.get(locale, 'settings_off'),
                      isActive: soundEnabled,
                      onTap: () {
                        ref.read(soundEnabledProvider.notifier).update((state) => !state);
                        ref.read(audioServiceProvider).playClick(ref);
                      },
                    ),

                    // Müzik Seçeneği
                    buildSettingRow(
                      label: AppStrings.get(locale, 'settings_music'),
                      valueText: musicEnabled ? AppStrings.get(locale, 'settings_on') : AppStrings.get(locale, 'settings_off'),
                      isActive: musicEnabled,
                      onTap: () {
                        ref.read(musicEnabledProvider.notifier).update((state) => !state);
                        ref.read(audioServiceProvider).playClick(ref);
                        ref.read(audioServiceProvider).updateBgmState(ref);
                      },
                    ),

                    // Titreşim Seçeneği
                    buildSettingRow(
                      label: AppStrings.get(locale, 'settings_vibrate'),
                      valueText: vibrateEnabled ? AppStrings.get(locale, 'settings_on') : AppStrings.get(locale, 'settings_off'),
                      isActive: vibrateEnabled,
                      onTap: () {
                        ref.read(vibrateEnabledProvider.notifier).update((state) => !state);
                        ref.read(audioServiceProvider).triggerVibration(ref, type: HapticType.medium);
                      },
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        sharedPrefs.clear();
                        ref.read(gameProvider.notifier).resetGame();
                        ref.read(localeProvider.notifier).update((s) => 'en');
                        ref.read(soundEnabledProvider.notifier).update((s) => true);
                        ref.read(musicEnabledProvider.notifier).update((s) => true);
                        ref.read(vibrateEnabledProvider.notifier).update((s) => true);
                        setState(() {
                          _commentaryLogs.clear();
                          _commentaryLogs.add(AppStrings.get('en', 'commentary_ready'));
                          _offlineDialogShown = false;
                          _selectedHorseIndex = 0;
                          _selectedJockeyIndex = 0;
                          _lastTickHorseOrder = null;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.salmonPink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        locale == 'tr' ? 'Oyunu Sıfırla' : 'Reset Game',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mutedBrown,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        AppStrings.get(locale, 'settings_close'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatNumber(double n) {
    return AppStrings.formatGold(n);
  }

  String _ordinalSuffix(int rank) {
    final locale = ref.read(localeProvider);
    if (locale == 'tr') {
      return '$rank.';
    }
    if (rank == 1) {
      return '1st';
    }
    if (rank == 2) {
      return '2nd';
    }
    if (rank == 3) {
      return '3rd';
    }
    return '${rank}th';
  }

  void _upgradeHorseStat(int chronologicalIndex, String statId) {
    final gameState = ref.read(gameProvider);
    final sortedHorses = List<HorseAsset>.from(gameState.horses)
      ..sort((a, b) => a.associatedLeagueTier.compareTo(b.associatedLeagueTier));
    final horse = sortedHorses[chronologicalIndex];
    final realIndex = gameState.horses.indexWhere((h) => h.id == horse.id);

    final notifier = ref.read(gameProvider.notifier);
    notifier.upgradeHorseStat(realIndex, statId);
    ref.read(audioServiceProvider).playUpgrade(ref);
  }

  void _upgradeJockeySkill(int jockeyIndex, String skillId) {
    final notifier = ref.read(gameProvider.notifier);
    notifier.upgradeJockeySkill(jockeyIndex, skillId);
    ref.read(audioServiceProvider).playUpgrade(ref);
  }

  void _upgradeBuilding(String buildingId) {
    final notifier = ref.read(gameProvider.notifier);
    notifier.upgradeBuilding(buildingId);
    ref.read(audioServiceProvider).playUpgrade(ref);
  }

  void _showNameEditDialog(bool isHorse, int tier) {
    final gameState = ref.read(gameProvider);
    final locale = ref.read(localeProvider);
    final String currentName = isHorse
        ? (tier < gameState.horses.length ? gameState.horses[tier].name : '')
        : (tier < gameState.jockeys.length ? gameState.jockeys[tier].name : '');

    final TextEditingController textController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFF1EADF), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isHorse
                      ? (locale == 'tr' ? 'Atı Yeniden Adlandır' : 'Rename Horse')
                      : (locale == 'tr' ? 'Jokeyi Yeniden Adlandır' : 'Rename Jockey'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  autofocus: true,
                  maxLength: 20,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AppTheme.charcoalBrown,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: currentName,
                    hintStyle: const TextStyle(color: AppTheme.mutedBrown),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFFFAF6EE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF1EADF), width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFF1EADF), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.mintGreen, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF1EADF), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          locale == 'tr' ? 'İptal' : 'Cancel',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mutedBrown,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final newName = textController.text.trim();
                          if (newName.isNotEmpty && newName != currentName) {
                            Navigator.pop(context); // Close edit dialog
                            _watchAdAndSaveName(isHorse, tier, newName);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mintGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.ondemand_video_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              locale == 'tr' ? 'Kaydet' : 'Save',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _watchAdAndSaveName(bool isHorse, int tier, String newName) {
    final locale = ref.read(localeProvider);
    final notifier = ref.read(gameProvider.notifier);
    final nav = Navigator.of(context);

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
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
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
        nav.pop(); // Close ad loading dialog
      }

      bool success = false;
      if (isHorse) {
        success = notifier.renameHorse(tier, newName);
      } else {
        success = notifier.renameJockey(tier, newName);
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locale == 'tr'
                  ? 'İsim başarıyla güncellendi!'
                  : 'Name successfully updated!',
              style: const TextStyle(fontFamily: 'Outfit'),
            ),
            backgroundColor: AppTheme.mintGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _openLeagueChest(int chestTier, bool withGold) {
    final notifier = ref.read(gameProvider.notifier);
    final result = notifier.openLeagueChest(chestTier, withGold);
    if (result != null) {
      _showLeagueGachaResultDialog(result);
    }
  }

  void _showLeagueGachaResultDialog(Map<String, dynamic> result) {
    final bool isHorse = result['isHorse'] as bool;
    final String name = result['name'] as String;
    final int tier = result['tier'] as int;
    final double stars = (result['stars'] as num).toDouble();
    final locale = ref.read(localeProvider);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: const BorderSide(color: Color(0xFFF1EADF), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.get(locale, 'card_drawn_title'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.mintGreen, width: 2.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isHorse
                            ? CategoryConfig.categories[tier].asset1Emoji
                            : CategoryConfig.categories[tier].asset2Emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${locale == 'tr' ? (isHorse ? CategoryConfig.categories[tier].asset1SingleTr : CategoryConfig.categories[tier].asset2SingleTr) : (isHorse ? CategoryConfig.categories[tier].asset1SingleEn : CategoryConfig.categories[tier].asset2SingleEn)} - ${AppStrings.get(locale, "tier_label")} ${tier + 1}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          color: AppTheme.mutedBrown,
                        ),
                      ),
                      const SizedBox(height: 10),
                       _buildStarRow(stars, size: 20),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.get(locale, 'card_dup_note'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          color: AppTheme.mutedBrown,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  child: Text(AppStrings.get(locale, 'excellent_btn')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProbabilityInfoDialog({required bool isHorse, required bool isRare}) {
    final gameState = ref.read(gameProvider);
    final locale = ref.read(localeProvider);

    double maxStars = 1.0;
    for (int i = 0; i <= 4; i++) {
      final currentStars = isHorse 
          ? gameState.horses[i].currentStars 
          : gameState.jockeys[i].currentStars;
      if (currentStars > 0.0) {
        double stars = (i + 1).toDouble();
        if (stars > maxStars) {
          maxStars = stars;
        }
      }
    }
    int highestStars = maxStars.toInt();
    if (highestStars > 4) highestStars = 4;

    List<double> displayRates = List.filled(6, 0.0);
    List<int> displayedTiers = [];

    if (isRare) {
      if (highestStars == 1) {
        displayRates[1] = 10.0;
        displayRates[2] = 20.0;
        displayRates[3] = 30.0;
        displayRates[4] = 40.0;
        displayedTiers = [1, 2, 3, 4];
      } else if (highestStars == 2) {
        displayRates[2] = 20.0;
        displayRates[3] = 35.0;
        displayRates[4] = 45.0;
        displayedTiers = [2, 3, 4];
      } else if (highestStars == 3) {
        displayRates[3] = 45.0;
        displayRates[4] = 55.0;
        displayedTiers = [3, 4];
      } else {
        displayRates[4] = 95.0;
        displayRates[5] = 5.0;
        displayedTiers = [4, 5];
      }
    } else {
      if (highestStars == 1) {
        displayRates[1] = 65.0;
        displayRates[2] = 30.0;
        displayRates[3] = 4.0;
        displayRates[4] = 1.0;
        displayedTiers = [1, 2, 3, 4];
      } else if (highestStars == 2) {
        displayRates[2] = 65.0;
        displayRates[3] = 30.0;
        displayRates[4] = 5.0;
        displayedTiers = [2, 3, 4];
      } else if (highestStars == 3) {
        displayRates[3] = 90.0;
        displayRates[4] = 10.0;
        displayedTiers = [3, 4];
      } else {
        displayRates[4] = 95.0;
        displayRates[5] = 5.0;
        displayedTiers = [4, 5];
      }
    }

    String getHorseEmoji(int idx) {
      switch (idx) {
        case 0: return '🐴';
        case 1: return '🐎';
        case 2: return '🏇';
        case 3: return '⚡';
        case 4: return '🌟';
        case 5: return '🦄';
        default: return '🐴';
      }
    }

    String getJockeyEmoji(int idx) {
      switch (idx) {
        case 0: return '🤠';
        case 1: return '👩‍🌾';
        case 2: return '🏎️';
        case 3: return '🧑‍🚀';
        case 4: return '🦸';
        case 5: return '👑';
        default: return '👨‍🌾';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFFF1EADF), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isHorse
                            ? (isRare
                                ? (locale == 'tr' ? 'Nadir At Parçası Olasılıkları' : 'Rare Horse Fragment Drop Rates')
                                : (locale == 'tr' ? 'Standart At Parçası Olasılıkları' : 'Standard Horse Fragment Drop Rates'))
                            : (isRare
                                ? (locale == 'tr' ? 'Nadir Jokey Parçası Olasılıkları' : 'Rare Jockey Fragment Drop Rates')
                                : (locale == 'tr' ? 'Standart Jokey Parçası Olasılıkları' : 'Standard Jockey Fragment Drop Rates')),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF6EE),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF1EADF)),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.mutedBrown),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(displayedTiers.length, (i) {
                        final index = displayedTiers[i];
                        final rate = displayRates[index];
                        final double targetStars = index == 5 ? 6.0 : (index + 1).toDouble();
                        
                        final String name = isHorse
                            ? gameState.horses[index].name
                            : gameState.jockeys[index].name;
                        final String emoji = isHorse ? getHorseEmoji(index) : getJockeyEmoji(index);
                        
                        final bool isUnlocked = isHorse
                            ? (gameState.horses[index].currentStars > 0.0)
                            : (gameState.jockeys[index].currentStars > 0.0);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 5.0),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUnlocked
                                  ? AppTheme.mintGreen.withValues(alpha: 0.15)
                                  : const Color(0xFFF1EADF),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              _buildStarRow(targetStars, size: 10),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isUnlocked
                                        ? AppTheme.charcoalBrown
                                        : AppTheme.charcoalBrown.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUnlocked
                                      ? const Color(0xFFF3F4F6)
                                      : AppTheme.mintGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isUnlocked
                                      ? (locale == 'tr' ? '0% (Açıldı)' : '0% (Unlocked)')
                                      : '${rate.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    color: isUnlocked ? AppTheme.mutedBrown : AppTheme.mintGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLootboxResultDialog(dynamic result) {
    if (result == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LootboxRevealDialog(result: result),
    );
  }

  void _performMerge(bool isHorse, int index) {
    final notifier = ref.read(gameProvider.notifier);
    final result = notifier.mergeAsset(isHorse, index);
    final locale = ref.read(localeProvider);

    if (result != null) {
      _showMergeSuccessDialog(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get(locale, 'merge_error')),
          backgroundColor: AppTheme.salmonPink,
        ),
      );
    }
  }

  void _showMergeSuccessDialog(Map<String, dynamic> result) {
    final bool isHorse = result['isHorse'] as bool;
    final String name = result['name'] as String;
    final int stars = result['stars'] as int;
    final int tier = result['tier'] as int;
    final locale = ref.read(localeProvider);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.creamBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.get(locale, 'merge_success_title'),
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.amber, width: 2.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isHorse
                            ? '${CategoryConfig.categories[tier].asset1Emoji}✨'
                            : '${CategoryConfig.categories[tier].asset2Emoji}✨',
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final bool isHighlighted = index < stars;
                          return Icon(
                            Icons.star_rounded,
                            color: isHighlighted ? Colors.amber : Colors.grey.withValues(alpha: 0.3),
                            size: 24,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locale == 'tr'
                            ? '$stars Yıldıza Yükseltildi!'
                            : 'Upgraded to $stars Stars!',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  child: Text(AppStrings.get(locale, 'awesome_btn')),
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

    // Ensure selected horse index is valid
    if (_selectedHorseIndex >= gameState.horses.length) {
      _selectedHorseIndex = 0;
    }

    if (gameState.currentTabIndex == 1 && _lastTabIndex != 1) {
      _lastTabIndex = 1;
      final activeIndex = gameState.horses[gameState.leagueTier].associatedLeagueTier;
      _selectedHorseIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveHorse(gameState);
      });
    } else if (gameState.currentTabIndex == 2 && _lastTabIndex != 2) {
      _lastTabIndex = 2;
      final activeIndex = gameState.leagueTier.clamp(0, gameState.jockeys.length - 1);
      _selectedJockeyIndex = activeIndex;
    } else if (gameState.currentTabIndex != 1 && gameState.currentTabIndex != 2) {
      _lastTabIndex = gameState.currentTabIndex;
    }

    // Ensure selected indices are valid
    if (_selectedHorseIndex >= gameState.horses.length) {
      _selectedHorseIndex = 0;
    }
    if (_selectedJockeyIndex >= gameState.jockeys.length) {
      _selectedJockeyIndex = 0;
    }

    ref.listen<GameStateModel>(gameProvider, (previous, next) {
      if (previous == null) { return; }
      final locale = ref.read(localeProvider);

      // Lig terfi
      if (next.unlockedLeagueTier > previous.unlockedLeagueTier) {
        _showPromotionDialog(next.leagueTier, next.currentDerbyLeague);
      }

      // Yarış başlangıcı
      if (next.raceState == 'racing' && previous.raceState == 'results') {
        _lastTickHorseOrder = null;
        _addCommentary(AppStrings.get(locale, 'commentary_gates_open'));
      }

      // Yarış bitti - sonuçlar ekranına geçiş
      if (next.raceState == 'results' && previous.raceState == 'racing') {
        final rank = next.lastRacePlacement;
        final suffix = _ordinalSuffix(rank);
        String msg;
        if (rank == 1) {
          msg = locale == 'tr'
              ? '🏆 KAZANDIN! $suffix bitirdin! +${next.lastRaceGoldEarned.toStringAsFixed(0)} altın ve +1 elmas!'
              : '🏆 YOU WON! Finished $suffix! +${next.lastRaceGoldEarned.toStringAsFixed(0)} gold and +1 diamond!';
        } else if (rank == 2) {
          msg = locale == 'tr'
              ? '🎽 $suffix bitirdin! +${next.lastRaceGoldEarned.toStringAsFixed(0)} altın ve +1 elmas kazandın.'
              : '🎽 Finished $suffix! Earned +${next.lastRaceGoldEarned.toStringAsFixed(0)} gold and +1 diamond.';
        } else if (rank == 3) {
          msg = locale == 'tr'
              ? '🎽 $suffix bitirdin! +${next.lastRaceGoldEarned.toStringAsFixed(0)} altın kazandın.'
              : '🎽 Finished $suffix! Earned +${next.lastRaceGoldEarned.toStringAsFixed(0)} gold.';
        } else {
          msg = locale == 'tr'
              ? '😤 $suffix bitirdin. Daha sert antren et!'
              : '😤 Finished $suffix. Train harder!';
        }
        _addCommentary(msg);
      }



      // ─── Real-Time Overtake Commentary & Live Position Listening ───
      if (next.raceState == 'racing') {
        final currentOrder = List.generate(5, (i) => MapEntry(i, next.horsePositions[i]))
          ..sort((a, b) => b.value.compareTo(a.value));
        final currentOrderKeys = currentOrder.map((e) => e.key).toList();

        if (_lastTickHorseOrder != null && _lastTickHorseOrder!.length == 5) {
          int? overtookHorseA;
          int? overtakenHorseB;
          int newRank = 0;

          // Check if any horse A overtook horse B
          for (int rankA = 0; rankA < 5; rankA++) {
            final A = currentOrderKeys[rankA];
            final prevIdxA = _lastTickHorseOrder!.indexOf(A);

            for (int rankB = rankA + 1; rankB < 5; rankB++) {
              final B = currentOrderKeys[rankB];
              final prevIdxB = _lastTickHorseOrder!.indexOf(B);

              if (prevIdxA > prevIdxB) {
                // A was behind B in previous tick, but is ahead of B now!
                // A overtook B!
                overtookHorseA = A;
                overtakenHorseB = B;
                newRank = rankA + 1;
                break;
              }
            }
            if (overtookHorseA != null) break;
          }

          if (overtookHorseA != null && overtakenHorseB != null) {
            final String aName = overtookHorseA == 0
                ? next.horses[next.leagueTier].name
                : next.currentRaceRivalNames[overtookHorseA - 1];
            final String bName = overtakenHorseB == 0
                ? next.horses[next.leagueTier].name
                : next.currentRaceRivalNames[overtakenHorseB - 1];
            final suffix = _ordinalSuffix(newRank);

            final String commentaryLine = locale == 'tr'
                ? '$aName, $bName isimli atı geçerek $suffix sıraya yerleşti!'
                : '$aName overtakes $bName for $suffix place!';

            _addCommentary(commentaryLine);
          }
        }
        _lastTickHorseOrder = currentOrderKeys;
      }

      // Ara yorum
      if (next.raceState == 'racing' && next.raceTimeLeft % 100 == 0 && next.raceTimeLeft > 0) {
        final sorted = List.generate(5, (i) => MapEntry(i, next.horsePositions[i]))
          ..sort((a, b) => b.value.compareTo(a.value));
        final leader = sorted[0].key;
        if (leader == 0) {
          final pName = next.horses[next.leagueTier].name;
          if (locale == 'tr') {
            _addCommentary('⚡ Kulvar ${next.playerGateNumber + 1} [$pName] önde! Tempoyu koruyor!');
          } else {
            _addCommentary('⚡ Gate ${next.playerGateNumber + 1} [$pName] is leading! Keeping the pace!');
          }
        } else {
          final rName = next.currentRaceRivalNames[leader - 1];
          int rivalGate = 0;
          for (int g = 0; g < 5; g++) {
            final bool isPlayer = g == next.playerGateNumber;
            final int displayRivalIdx = isPlayer ? -1 : (g < next.playerGateNumber ? g + 1 : g);
            if (displayRivalIdx == leader) {
              rivalGate = g + 1;
              break;
            }
          }
          if (locale == 'tr') {
            _addCommentary('🐎 Kulvar $rivalGate [$rName] öne geçti!');
          } else {
            _addCommentary('🐎 Gate $rivalGate [$rName] is taking the lead!');
          }
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── TOP HUD ───
            _buildTopHud(gameState, notifier),
            const Divider(height: 1),

            // ─── MAIN CONTENT ───
            Expanded(
              child: Column(
                children: [
                  // Yarış Alanı (Üst %45)
                  Expanded(
                    flex: 45,
                    child: _buildRaceArea(gameState, notifier),
                  ),
                  // Dashboard (Alt %55)
                  Expanded(
                    flex: 55,
                    child: _buildTabContent(gameState, notifier),
                  ),
                ],
              ),
            ),

            // ─── BOTTOM NAV ───
            _buildBottomTabBar(gameState, notifier),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  TOP HUD
  // ═══════════════════════════════════════════════════
  Widget _buildTopHud(GameStateModel gameState, GameNotifier notifier) {
    final bool boostActive = gameState.boostTimeLeft > 0;
    final int boostSecs = gameState.boostTimeLeft ~/ 10; // deciseconds -> seconds
    final locale = ref.watch(localeProvider);

    final currentLeagueName = locale == 'tr'
        ? CategoryConfig.categories[gameState.leagueTier.clamp(0, 5)].nameTr
        : CategoryConfig.categories[gameState.leagueTier.clamp(0, 5)].nameEn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Left Section (Clean Wealth & Settings) ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PulsingGoldWidget(gold: gameState.gold),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _showSettingsDialog();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFF1EADF),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          size: 20,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _showGlobalScoreboardDialog(gameState);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFF1EADF),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🏆',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Absolute Center Section (Income Hub) ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  locale == 'tr' ? 'Gelir/sn' : 'Income/sec',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mutedBrown,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${AppStrings.formatGold(gameState.goldPerSecond * math.pow(10.0, gameState.leagueTier))}${AppStrings.get(locale, 'passive_per_sec')}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 19.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                if (gameState.goldPerSecond > 0) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      if (!boostActive) {
                        notifier.activateBoost();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: boostActive ? const Color(0xFFFFE0B2) : AppTheme.salmonPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text(
                            boostActive
                                ? '${AppStrings.get(locale, 'boost_active')} (${boostSecs}s)'
                                : AppStrings.get(locale, 'boost_get'),
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: boostActive ? const Color(0xFFB8860B) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Right Section (Premium Diamonds & League Info) ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF1EADF),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('💎', style: TextStyle(fontSize: 14)),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                AppStrings.formatGold(gameState.diamonds.toDouble()),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showLeagueDialog(gameState, notifier),
                  child: Container(
                    width: 110,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2B2D), // Sleek solid Charcoal/Dark Grey
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            currentLeagueName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSingleLineInfoBar(GameStateModel gameState, int playerCurrentRank, String locale) {
    final winPct = '${(gameState.winChance * 100).round()}%';
    final winLabel = locale == 'tr' ? 'Kazanma Oranı' : 'Win Rate';
    final formLabel = locale == 'tr' ? 'Form' : 'Form';

    int activePower = 0;
    if (gameState.leagueTier >= 0 && gameState.leagueTier < gameState.horses.length && gameState.leagueTier < gameState.jockeys.length) {
      final horse = gameState.horses[gameState.leagueTier];
      final jockey = gameState.jockeys[gameState.leagueTier];
      int horseStatsSum = 0;
      horse.stats.forEach((key, level) {
        int baseVal = 0;
        switch (key) {
          case 'speed': baseVal = 10; break;
          case 'stamina': baseVal = 10; break;
          case 'acceleration': baseVal = 8; break;
          case 'focus': baseVal = 8; break;
          case 'cornering': baseVal = 4; break;
          case 'temper': baseVal = 10; break;
        }
        horseStatsSum += baseVal + (level - 1) * 3;
      });
      int jockeySkillsSum = 0;
      jockey.skills.forEach((key, level) {
        int baseVal = 0;
        switch (key) {
          case 'reflex': baseVal = 10; break;
          case 'balance': baseVal = 10; break;
          case 'tactics': baseVal = 8; break;
          case 'control': baseVal = 8; break;
          case 'condition': baseVal = 8; break;
          case 'motivation': baseVal = 6; break;
        }
        jockeySkillsSum += baseVal + (level - 1) * 3;
      });
      activePower = horseStatsSum + _getStarBonus(horse.currentStars) + jockeySkillsSum + _getStarBonus(jockey.currentStars);
    }
    String formatPower(int power) {
      if (power < 1000) return '$power';
      double kPower = power / 1000.0;
      return '${kPower.toStringAsFixed(1)}k';
    }
    final powerStr = formatPower(activePower);

    Widget infoCol({
      String? label,
      Widget? labelWidget,
      required Widget valueWidget,
      CrossAxisAlignment align = CrossAxisAlignment.center,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align,
        children: [
          if (labelWidget != null)
            labelWidget
          else if (label != null)
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white60,
                letterSpacing: 0.3,
              ),
            ),
          const SizedBox(height: 2),
          valueWidget,
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: Win Chance & Team Power ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              infoCol(
                label: winLabel,
                align: CrossAxisAlignment.center,
                valueWidget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    winPct,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF69F0AE),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              infoCol(
                label: locale == 'tr' ? 'Takım Gücü' : 'Team Power',
                align: CrossAxisAlignment.center,
                valueWidget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    powerStr,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD54F),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Center: Blinking LIVE/CANLI badge ──
          infoCol(
            labelWidget: const SizedBox(height: 11),
            align: CrossAxisAlignment.center,
            valueWidget: _LiveBadge(locale: locale),
          ),

          // ── Right: Last 5 Races form guide ──
          infoCol(
            label: formLabel,
            align: CrossAxisAlignment.center,
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                if (i >= gameState.recentPlacements.length) {
                  return Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: const Text('-', style: TextStyle(fontSize: 8, color: Colors.white38)),
                  );
                }
                final rank = gameState.recentPlacements[i];
                final Color boxColor = rank == 1
                    ? const Color(0xFF4CAF50)
                    : rank <= 3
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFE57373);
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: boxColor.withValues(alpha: 0.5),
                        blurRadius: 3,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTribuneArea(GameStateModel gameState, GameNotifier notifier) {
    // 5 distinct horse-representative colors for the spectator blocks
    // Order: Horse1=Red, Horse2=Blue, Horse3=Gold, Horse4=Green, Horse5=Purple
    const List<Color> horseColors = [
      Color(0xFFEF5350), // 🔴 Horse 1 – Red
      Color(0xFF42A5F5), // 🔵 Horse 2 – Blue
      Color(0xFFFFCA28), // 🟡 Horse 3 – Gold
      Color(0xFF66BB6A), // 🟢 Horse 4 – Green
      Color(0xFFAB47BC), // 🟣 Horse 5 – Purple
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int countPerRow = (width / 11.0).floor();

        // Fixed-seed RNG: gives a stable random-looking layout on every rebuild
        final rng = math.Random(31415);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Tribune grandstand: 3 rows of spectator blocks with staircase effect
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (rowIndex) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(countPerRow, (colIndex) {
                      final bool isStaircase = (colIndex % 6 == 5);

                      // Always consume one RNG value so column positions stay consistent
                      final int colorIdx = rng.nextInt(5);

                      if (isStaircase) {
                        return Container(
                          width: 6,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        );
                      }

                      final Color color = horseColors[colorIdx];
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
            // Sponsor Animation Track
            if (gameState.sponsorActive)
              Positioned(
                left: gameState.sponsorPosition * (width - 32),
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _showSponsorAdDialog(notifier),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: gameState.sponsorIsMega ? 34 : 30,
                        height: gameState.sponsorIsMega ? 34 : 30,
                        decoration: BoxDecoration(
                          color: gameState.sponsorIsMega ? const Color(0xFFFFD700) : AppTheme.softAmber,
                          shape: BoxShape.circle,
                          border: Border.all(color: gameState.sponsorIsMega ? Colors.amber.shade100 : Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: gameState.sponsorIsMega ? Colors.amber.withValues(alpha: 0.9) : AppTheme.softAmber.withValues(alpha: 0.6),
                              blurRadius: gameState.sponsorIsMega ? 14 : 8,
                              spreadRadius: gameState.sponsorIsMega ? 2 : 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(gameState.sponsorIsMega ? '👑' : '🎁', style: TextStyle(fontSize: gameState.sponsorIsMega ? 16 : 13)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRaceArea(GameStateModel gameState, GameNotifier notifier) {
    final int leagueTier = gameState.leagueTier.clamp(0, 5);
    final List<Color> trackGradient = _leagueTrackGradients[leagueTier];
    final locale = ref.watch(localeProvider);

    // Anlık sıralama (pozisyona göre)
    final List<MapEntry<int, double>> sortedPositions = List.generate(
      5,
      (i) => MapEntry(i, gameState.horsePositions[i]),
    )..sort((a, b) => b.value.compareTo(a.value));
    final int playerCurrentRank = sortedPositions.indexWhere((e) => e.key == 0) + 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: trackGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Pist içeriği
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Tek Satırlı Bilgi Çubuğu ───
                  _buildSingleLineInfoBar(gameState, playerCurrentRank, locale),
                  const SizedBox(height: 6),

                  // ─── 3-Satırlı Tribün (The Grandstand) ───
                  _buildTribuneArea(gameState, notifier),
                  const SizedBox(height: 6),



                  // ─── Pist Şeritleri ───
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: trackGradient[0].withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double trackWidth = constraints.maxWidth;
                          final double trackHeight = constraints.maxHeight;
                          final int horseCount = gameState.horsePositions.length;
                          final double laneHeight = trackHeight / (horseCount > 0 ? horseCount.toDouble() : 5.0);

                          return Column(
                            children: List.generate(horseCount, (index) {
                              final bool isPlayer = index == gameState.playerGateNumber;
                              final double pos = isPlayer
                                  ? gameState.horsePositions[0]
                                  : gameState.horsePositions[index < gameState.playerGateNumber ? index + 1 : index];

                              // Compact overlap: lanes slightly smaller + negative margin for perspective layering
                              final double compactHeight = laneHeight * (horseCount > 5 ? 0.88 : 1.0);
                              final double overlapMargin = horseCount > 5 ? -(laneHeight * 0.06) : 0.0;

                              final List<Color> horseColors = [
                                AppTheme.salmonPink,
                                const Color(0xFF9C27B0),
                                const Color(0xFFFF9800),
                                const Color(0xFF00BCD4),
                                const Color(0xFF3F51B5),
                                const Color(0xFF4CAF50),
                                const Color(0xFFE91E63),
                                const Color(0xFFFF5722),
                              ];
                              final Color indicatorColor = isPlayer
                                  ? horseColors[0]
                                  : horseColors[(index < gameState.playerGateNumber ? index + 1 : index) % horseColors.length];


                              return Padding(
                                padding: EdgeInsets.only(top: index == 0 ? 0 : overlapMargin.abs()),
                                child: SizedBox(
                                height: compactHeight,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Şerit arka planı
                                    Container(
                                      decoration: BoxDecoration(
                                        color: index.isEven
                                            ? Colors.white.withValues(alpha: 0.04)
                                            : Colors.transparent,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: index == horseCount - 1 ? Colors.transparent : Colors.white12,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // At ismi — zeminde yazı gibi, soluk ve sol kenarda
                                    Positioned(
                                      left: 6,
                                      top: 0,
                                      bottom: 0,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          () {
                                            final int rivalSlot = isPlayer ? -1 : (index < gameState.playerGateNumber ? index : index - 1);
                                            return isPlayer
                                                ? gameState.horses[gameState.leagueTier.clamp(0, gameState.horses.length - 1)].name
                                                : gameState.currentRaceRivalNames[rivalSlot.clamp(0, gameState.currentRaceRivalNames.length - 1)];
                                          }(),
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: isPlayer
                                                ? Colors.white.withValues(alpha: 0.30)
                                                : Colors.white.withValues(alpha: 0.18),
                                            letterSpacing: 0.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),

                                    // Bitiş çizgisi (en sağda)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 3,
                                      child: Container(color: Colors.white24),
                                    ),

                                    // At ikonu (AnimatedPositioned - 100ms, en soldan başlayıp en sağa gider)
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 100),
                                      curve: Curves.linear,
                                      left: pos * (trackWidth - 32.0),
                                      top: (compactHeight - 22.0) / 2.0,
                                      child: Container(
                                        width: 28,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: indicatorColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isPlayer ? AppTheme.softAmber : Colors.white24,
                                            width: isPlayer ? 2 : 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: indicatorColor.withValues(alpha: 0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Transform.scale(
                                          scaleX: -1,
                                          child: Text(
                                            isPlayer
                                                ? CategoryConfig.categories[gameState.leagueTier].premiumAsset2Emoji
                                                : CategoryConfig.categories[gameState.leagueTier].asset1Emoji,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ), // SizedBox
                              ); // Padding
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sponsor flag removed from bottom and relocated to the Tribune above

            // ─── Sonuç Ekranı Overlay (5s = 50 tick) ───
            if (gameState.raceState == 'results')
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5), // Semi-transparent overlay dimming the background
                  child: Center(
                    child: Container(
                      width: 280, // Centered compact modal card width
                      decoration: BoxDecoration(
                        color: AppTheme.creamBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1EADF), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Prominent colored header container
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: gameState.lastRacePlacement == 1
                                  ? const Color(0xFFE5A93C) // Gold/amber for 1st
                                  : AppTheme.charcoalBrown, // Muted gray/charcoal for others
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(22),
                                topRight: Radius.circular(22),
                              ),
                            ),
                            child: Text(
                              gameState.lastRacePlacement == 1
                                  ? (locale == 'tr' ? '🏆 1. OLDUN!' : '🏆 1st PLACE!')
                                  : '${_ordinalSuffix(gameState.lastRacePlacement)} ${locale == 'tr' ? 'Bitirdin' : 'Place'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Content below header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Earned rewards
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🪙', style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${AppStrings.formatGold(gameState.lastRaceGoldEarned)}',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.charcoalBrown,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('🎯', style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${gameState.lastRacePointsEarned.toStringAsFixed(0)} ${locale == 'tr' ? "puan" : "pts"}',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.mutedBrown,
                                      ),
                                    ),
                                    if (gameState.lastRacePlacement == 1 || gameState.lastRacePlacement == 2) ...[
                                      const SizedBox(width: 12),
                                      const Text('💎', style: TextStyle(fontSize: 18)),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '+1',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.charcoalBrown,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Season Info
                                Builder(
                                  builder: (context) {
                                    final int matchCap = _matchCapForClass(gameState.currentClassIndex);
                                    final int currentRank = gameState.rivalSeasonPoints.where((rp) => rp > gameState.seasonPoints).length + 1;
                                    if (gameState.currentSeasonRace >= matchCap) {
                                      return Text(
                                        locale == 'tr'
                                            ? 'Sezonu $currentRank. Tamamladın!'
                                            : 'You finished the season in ${_ordinalSuffix(currentRank)} place!',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.charcoalBrown,
                                        ),
                                      );
                                    } else {
                                      final int remainingMatches = matchCap - gameState.currentSeasonRace;
                                      return Text(
                                        locale == 'tr'
                                            ? 'Kalan Maç: $remainingMatches'
                                            : 'Remaining Matches: $remainingMatches',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.mutedBrown,
                                        ),
                                      );
                                    }
                                  }
                                ),
                                const SizedBox(height: 16),
                                // Progress bar that drains from right to left (value is resultsCountdown / 50.0)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (gameState.resultsCountdown / 50.0).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFF1EADF),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      gameState.lastRacePlacement == 1
                                          ? const Color(0xFFE5A93C)
                                          : AppTheme.mintGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  TAB İÇERİKLERİ
  // ═══════════════════════════════════════════════════
  Widget _buildTabContent(GameStateModel gameState, GameNotifier notifier) {
    switch (gameState.currentTabIndex) {
      case 0:
        return _buildDerbyTab(gameState, notifier);
      case 1:
        return _buildStableTab(gameState, notifier);
      case 2:
        return _buildJockeysTab(gameState, notifier);
      case 3:
        return _buildFacilitiesTab(gameState, notifier);
      case 4:
        return _buildMarketTab(gameState, notifier);
      default:
        return _buildDerbyTab(gameState, notifier);
    }
  }

  // ─── DERBY TAB ───
  Widget _buildDerbyTab(GameStateModel gameState, GameNotifier notifier) {
    final locale = ref.watch(localeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          // ─── Canlı Anlatım Kutusu (3 satır) ───
          Container(
            height: 72,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1EADF), width: 1.5),
            ),
            child: Row(
              children: [
                const Text('🎙️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: math.min(3, _commentaryLogs.length),
                    itemBuilder: (context, index) {
                      return Text(
                        _commentaryLogs[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10.5,
                          color: index == 0 ? AppTheme.charcoalBrown : AppTheme.mutedBrown,
                          fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),


          // ─── Aktif Takım Kartı (Redesigned Premium Dashboard Card) ───
          if (gameState.leagueTier < gameState.horses.length &&
              gameState.leagueTier < gameState.jockeys.length)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFF1EADF),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Card Header ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.mintGreen.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.sports_score_rounded,
                                color: AppTheme.mintGreen,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locale == 'tr'
                                  ? ['Yerel Amatör Kupası','Bölgesel Profesyonel Lig','Ulusal Grand Prix','Kıtasal Şampiyona','Dünya Şampiyonlar Derbisi'][gameState.currentClassIndex.clamp(0,4)]
                                  : ['Local Amateur Cup','Regional Professional League','National Grand Prix','Continental Championship','World Champions Derby'][gameState.currentClassIndex.clamp(0,4)],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: AppTheme.charcoalBrown,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _ClassProgressBar(currentIndex: gameState.currentClassIndex, locale: locale),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Active Competitors (Horse & Jockey) ---
                  Row(
                    children: [
                      // Horse card section
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF6EE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF1EADF),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(CategoryConfig.categories[gameState.leagueTier].asset1Emoji, style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      gameState.horses[gameState.leagueTier].name,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.charcoalBrown,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _showNameEditDialog(true, gameState.leagueTier),
                                    child: const Icon(Icons.edit_rounded, size: 12, color: AppTheme.mutedBrown),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _buildStarRow(gameState.horses[gameState.leagueTier].currentStars, size: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Jockey card section
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF6EE),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF1EADF),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(CategoryConfig.categories[gameState.leagueTier].asset2Emoji, style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      gameState.jockeys[gameState.leagueTier].name,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.charcoalBrown,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _showNameEditDialog(false, gameState.leagueTier),
                                    child: const Icon(Icons.edit_rounded, size: 12, color: AppTheme.mutedBrown),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _buildStarRow(gameState.jockeys[gameState.leagueTier].currentStars, size: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Progress Bar & Compact Stats Footer ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Merged Match + Rank row
                      Builder(
                        builder: (context) {
                          final int currentRank = gameState.rivalSeasonPoints.where((rp) => rp > gameState.seasonPoints).length + 1;
                          final String rankSuffix = locale == 'tr'
                              ? '$currentRank.'
                              : currentRank == 1 ? '1st' : currentRank == 2 ? '2nd' : currentRank == 3 ? '3rd' : '${currentRank}th';
                          final int matchCap = _matchCapForClass(gameState.currentClassIndex);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                locale == 'tr'
                                    ? 'Mevcut Sezon ${gameState.currentSeasonRace - 1}/$matchCap'
                                    : 'Current Season ${gameState.currentSeasonRace - 1}/$matchCap',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.mutedBrown,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: currentRank == 1 ? AppTheme.softAmber.withValues(alpha: 0.2) : const Color(0xFFF1EADF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${locale == 'tr' ? 'Sıralama: ' : 'Rank: '}$rankSuffix',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: currentRank == 1 ? const Color(0xFFE5A93C) : AppTheme.charcoalBrown,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final int matchCap = _matchCapForClass(gameState.currentClassIndex);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ((gameState.currentSeasonRace - 1) / matchCap.toDouble()).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: const Color(0xFFF1EADF),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintGreen),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => _SeasonDetailsDialog(
                              gameState: gameState,
                              locale: locale,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mintGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          locale == 'tr' ? 'Detaylar' : 'Details',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          
          // ─── TEST PANEL (Relocated inside Race View / Derby Tab) ───
          _buildTestPanel(gameState, notifier),
        ],
      ),
    );
  }

  Widget _buildTestPanel(GameStateModel gameState, GameNotifier notifier) {
    final locale = ref.watch(localeProvider);
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale == 'tr' ? '🧪 Test Paneli' : '🧪 Test Panel',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                locale == 'tr'
                  ? 'Mevcut: ${["Yerel Amatör Kupası","Bölgesel Profesyonel Lig","Ulusal Grand Prix","Kıtasal Şampiyona","Dünya Şampiyonlar Derbisi"][gameState.currentClassIndex.clamp(0,4)]}'
                  : 'Current: ${["Local Amateur Cup","Regional Professional League","National Grand Prix","Continental Championship","World Champions Derby"][gameState.currentClassIndex.clamp(0,4)]}',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Klasman Arttır
              Expanded(
                child: ElevatedButton(
                  onPressed: () => notifier.debugChangeClass(true),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    backgroundColor: const Color(0xFF42A5F5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    locale == 'tr' ? 'Klasman +' : 'Class +',
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Klasman Azalt
              Expanded(
                child: ElevatedButton(
                  onPressed: () => notifier.debugChangeClass(false),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    backgroundColor: const Color(0xFFEF5350),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    locale == 'tr' ? 'Klasman -' : 'Class -',
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Coin +5k
              Expanded(
                child: ElevatedButton(
                  onPressed: () => notifier.debugAddGold(5000.0),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    backgroundColor: const Color(0xFF66BB6A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Coin +5k',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Elmas +100
              Expanded(
                child: ElevatedButton(
                  onPressed: () => notifier.debugAddDiamonds(100),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    backgroundColor: const Color(0xFFBA68C8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    locale == 'tr' ? 'Elmas +100' : 'Dia +100',
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── STABLES TAB ───
  Widget _buildStableTab(GameStateModel gameState, GameNotifier notifier) {
    final locale = ref.watch(localeProvider);

    int getStatValue(String id, int level) {
      int baseVal = 0;
      switch (id) {
        case 'speed':
          baseVal = 10;
          break;
        case 'stamina':
          baseVal = 10;
          break;
        case 'acceleration':
          baseVal = 8;
          break;
        case 'focus':
          baseVal = 8;
          break;
        case 'cornering':
          baseVal = 4;
          break;
        case 'temper':
          baseVal = 10;
          break;
        default:
          baseVal = 0;
      }
      return baseVal + (level - 1) * 3;
    }
    final stats = [
      {
        'id': 'speed',
        'name': AppStrings.get(locale, 'stat_speed_name'),
        'emoji': '👟',
        'desc': AppStrings.get(locale, 'stat_speed_desc')
      },
      {
        'id': 'acceleration',
        'name': AppStrings.get(locale, 'stat_acceleration_name'),
        'emoji': '⚡',
        'desc': AppStrings.get(locale, 'stat_acceleration_desc')
      },
      {
        'id': 'stamina',
        'name': AppStrings.get(locale, 'stat_stamina_name'),
        'emoji': '🔋',
        'desc': AppStrings.get(locale, 'stat_stamina_desc')
      },
      {
        'id': 'focus',
        'name': AppStrings.get(locale, 'stat_focus_name'),
        'emoji': '👁️',
        'desc': AppStrings.get(locale, 'stat_focus_desc')
      },
      {
        'id': 'temper',
        'name': AppStrings.get(locale, 'stat_temper_name'),
        'emoji': '🧘',
        'desc': AppStrings.get(locale, 'stat_temper_desc')
      },
      {
        'id': 'cornering',
        'name': AppStrings.get(locale, 'stat_cornering_name'),
        'emoji': '🔄',
        'desc': AppStrings.get(locale, 'stat_cornering_desc')
      },
    ];

    final sortedHorses = List<HorseAsset>.from(gameState.horses)
      ..sort((a, b) => a.associatedLeagueTier.compareTo(b.associatedLeagueTier));
    final selectedHorse = sortedHorses[_selectedHorseIndex];
    final bool isSelectedHorseUnlocked = selectedHorse.currentStars > 0;
    final int speedVal = getStatValue('speed', selectedHorse.stats['speed'] ?? 1);
    final int staminaVal = getStatValue('stamina', selectedHorse.stats['stamina'] ?? 1);
    final int accelVal = getStatValue('acceleration', selectedHorse.stats['acceleration'] ?? 1);
    final int focusVal = getStatValue('focus', selectedHorse.stats['focus'] ?? 1);
    final int temperVal = getStatValue('temper', selectedHorse.stats['temper'] ?? 1);
    final int corneringVal = getStatValue('cornering', selectedHorse.stats['cornering'] ?? 1);
    final int horseTotalPower = speedVal + staminaVal + accelVal + focusVal + temperVal + corneringVal + _getStarBonus(selectedHorse.currentStars);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Two horizontally split lootbox card containers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Left Card (Standart At - Light Blue Palette)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE), // Soft light blue/cyan tint
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0284C7), width: 1.5), // Strong Koyu Mavi border
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'STANDARD PART',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E3A8A), // Strong Koyu Mavi
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _showProbabilityInfoDialog(isHorse: true, isRare: false);
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 2.0),
                                child: Text('ℹ️', style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // 1x Open Button
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    locale == 'tr' ? 'Aç X1' : 'Open X1',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 32,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: gameState.tickets >= 1
                                          ? () {
                                              final result = notifier.openStandardChest1xTicket();
                                              if (result != null) {
                                                _showLootboxResultDialog(result);
                                              }
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3A8A),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        '1 🎫',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 10x Open Button
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    locale == 'tr' ? 'Aç X10' : 'Open X10',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 32,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: gameState.diamonds >= 100
                                          ? () {
                                              final result = notifier.openStandardChest10xDiamonds();
                                              if (result != null) {
                                                _showLootboxResultDialog(result);
                                              }
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3A8A),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        '100 💎',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Right Card (Nadir At - Purple Palette)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF), // Soft premium purple tint
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF7E22CE), width: 1.5), // Strong Koyu Mor border
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7E22CE).withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'RARE PART',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF581C87), // Strong Koyu Mor
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _showProbabilityInfoDialog(isHorse: true, isRare: true);
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 2.0),
                                child: Text('ℹ️', style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // 1x Open Button
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    locale == 'tr' ? 'Aç X1' : 'Open X1',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF581C87),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 32,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: gameState.diamonds >= 50
                                          ? () {
                                              final result = notifier.openNadirChest1xDiamonds();
                                              if (result != null) {
                                                _showLootboxResultDialog(result);
                                              }
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF581C87),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(0xFF581C87).withValues(alpha: 0.3),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        '50 💎',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 10x Open Button
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    locale == 'tr' ? 'Aç X10' : 'Open X10',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF581C87),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 32,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: gameState.diamonds >= 500
                                          ? () {
                                              final result = notifier.openNadirChest10xDiamonds();
                                              if (result != null) {
                                                _showLootboxResultDialog(result);
                                              }
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF581C87),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(0xFF581C87).withValues(alpha: 0.3),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        '500 💎',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 1. Header Pill Banner: AT GALERİSİ ───
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF3E2C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD68F1A), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              locale == 'tr' ? 'AT GALERİSİ' : 'HORSE GALLERY',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD700),
                letterSpacing: 0.8,
              ),
            ),
          ),

          // ─── 2. Horse Asset Cards Carousel Grid ───
          Container(
            height: 120,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.builder(
              controller: _horseScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: gameState.horses.length,
              itemBuilder: (context, index) {
                final sortedHorses = List<HorseAsset>.from(gameState.horses)
                  ..sort((a, b) => a.associatedLeagueTier.compareTo(b.associatedLeagueTier));
                final horse = sortedHorses[index];
                final mainIndex = index;
                final bool isSelected = _selectedHorseIndex == mainIndex;
                final bool isAssigned = horse.id == gameState.horses[gameState.leagueTier].id;
                final bool isUnlocked = horse.currentStars > 0;
                final double targetStars = index == 5 ? 6.0 : (index + 1).toDouble();

                String getHorseEmoji(int idx) {
                  const horseEmojis = ['🐴', '🐎', '🏇', '🐴', '🐎', '🏇'];
                  return horseEmojis[idx % horseEmojis.length];
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedHorseIndex = mainIndex;
                    });
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? (isAssigned || isSelected ? const Color(0xFFFAF8F5) : Colors.white)
                          : const Color(0xFFF0EAE1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAssigned
                            ? AppTheme.mintGreen
                            : (isSelected
                                ? const Color(0xFFD68F1A)
                                : (isUnlocked ? const Color(0xFFEFE8DE) : const Color(0xFFD1C7B7))),
                        width: isSelected || isAssigned ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected || isAssigned
                          ? [
                              BoxShadow(
                                color: (isAssigned ? AppTheme.mintGreen : const Color(0xFFD68F1A)).withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Horse Portrait Box
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isUnlocked ? AppTheme.creamBackground : const Color(0xFFE5DDD0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                getHorseEmoji(index),
                                style: TextStyle(
                                  fontSize: 24,
                                  color: isUnlocked ? null : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              horse.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: isUnlocked ? AppTheme.charcoalBrown : AppTheme.mutedBrown,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _buildStarRow(targetStars, size: 8),
                            const SizedBox(height: 4),
                            if (isUnlocked)
                              if (isAssigned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintGreen,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    locale == 'tr' ? 'SEÇİLİ' : 'ACTIVE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    notifier.assignHorse(horse.id, gameState.leagueTier);
                                    setState(() {
                                      _selectedHorseIndex = mainIndex;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.mintGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.mintGreen, width: 1),
                                    ),
                                    child: Text(
                                      locale == 'tr' ? 'SEÇ' : 'SELECT',
                                      style: const TextStyle(
                                        color: AppTheme.mintGreen,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  locale == 'tr' ? '🧩 ${horse.duplicateCardCount}/20 parça' : '🧩 ${horse.duplicateCardCount}/20 cards',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Locked Chains & Padlock Overlay (Matching reference image)
                        if (!isUnlocked)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('⛓️', style: TextStyle(fontSize: 16)),
                                  Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── 3. Header Pill Banner: [HORSE NAME] AHIRLARI ───
          if (isSelectedHorseUnlocked) ...[
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3E2C1E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD68F1A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${selectedHorse.name.toUpperCase()} ${locale == 'tr' ? 'AHIRLARI' : 'STABLES'}',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                  letterSpacing: 0.6,
                ),
              ),
            ),

            // Power Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${selectedHorse.name} ${locale == 'tr' ? 'Ahırları' : 'Stables'}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildStarRow(selectedHorse.currentStars, size: 12),
                    ],
                  ),
                  Text(
                    '${locale == 'tr' ? 'Toplam Güç' : 'Total Power'}: $horseTotalPower',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.mintGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // ─── 4. Stat Upgrade 2x2 Grid Layout (Matching reference image!) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats.map((stat) {
                  final String id = stat['id'] as String;
                  final int level = selectedHorse.stats[id] ?? 0;
                  final double cost = notifier.getHorseStatUpgradeCost(selectedHorse.associatedLeagueTier, level, id);
                  final bool canAfford = gameState.gold >= cost;

                  final int currentVal = getStatValue(id, level);
                  final int nextVal = getStatValue(id, level + 1);

                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 32) / 2,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: canAfford ? AppTheme.mintGreen.withValues(alpha: 0.35) : const Color(0xFFF1EADF),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Header Inside Stat Card: Emoji Box + Stat Name & Level
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.creamBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
                                ),
                                alignment: Alignment.center,
                                child: Text(stat['emoji'] as String, style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (stat['name'] as String).toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.charcoalBrown,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${locale == 'tr' ? 'Lvl' : 'Lvl'} $level',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 9,
                                        color: AppTheme.mutedBrown,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Stat Value Transition Preview (10 -> 13)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$currentVal',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoalBrown,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.mintGreen),
                              const SizedBox(width: 6),
                              Text(
                                '$nextVal',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.mintGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Full Width Train Button (Matching reference image: Eğit: 🪙100)
                          SizedBox(
                            width: double.infinity,
                            height: 30,
                            child: ElevatedButton(
                              onPressed: () => _upgradeHorseStat(_selectedHorseIndex, id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canAfford ? AppTheme.mintGreen : const Color(0xFFEFE8DE),
                                foregroundColor: canAfford ? Colors.white : AppTheme.mutedBrown,
                                elevation: canAfford ? 1 : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                '${locale == 'tr' ? 'Eğit' : 'Train'}: 🪙${_formatNumber(cost)}',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1EADF), width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedHorse.name,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildStarRow(_selectedHorseIndex == 5 ? 6.0 : (1.0 + _selectedHorseIndex).toDouble(), size: 16),
                      const SizedBox(height: 16),
                      if (_selectedHorseIndex == 5) ...[
                        Text(
                          locale == 'tr' ? 'Elmas ile Satın Al' : 'Unlock with Diamonds',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mutedBrown,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (gameState.diamonds < 1500) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const MarketScreen()),
                              );
                              return;
                            }
                            final success = notifier.buyPremiumHorse(5);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(locale == 'tr'
                                      ? '✅ Pegasus VIP Atı Satın Alındı!'
                                      : '✅ Pegasus VIP Horse Purchased!'),
                                  backgroundColor: AppTheme.mintGreen,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          child: const Text(
                            '💎 1500',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else ...[
                        Text(
                          locale == 'tr' ? 'Parça Toplayarak Kilidini Aç' : 'Unlock with Fragments',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mutedBrown,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Fragment Progress Bar out of 20
                        Container(
                          width: 220,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                LinearProgressIndicator(
                                  value: (selectedHorse.duplicateCardCount / 20.0).clamp(0.0, 1.0),
                                  backgroundColor: Colors.transparent,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintGreen),
                                  minHeight: 20,
                                ),
                                Text(
                                  '${selectedHorse.duplicateCardCount}/20',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.charcoalBrown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 1,
                              width: 50,
                              color: Colors.black12,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                locale == 'tr' ? 'VEYA' : 'OR',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              height: 1,
                              width: 50,
                              color: Colors.black12,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const MarketScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          child: Text(
                            locale == 'tr' ? 'Parça Satın Al' : 'Buy Fragments',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
        ],
      ),
    );
  }

  // ─── JOCKEYS TAB ───
  Widget _buildJockeysTab(GameStateModel gameState, GameNotifier notifier) {
    final locale = ref.watch(localeProvider);


    final skills = [
      {'id': 'reflex', 'name': locale == 'tr' ? 'Refleks' : 'Reflex', 'emoji': '⚡', 'desc': locale == 'tr' ? 'Anlık tepki hızı' : 'Instant reaction speed'},
      {'id': 'balance', 'name': locale == 'tr' ? 'Denge' : 'Balance', 'emoji': '🤸', 'desc': locale == 'tr' ? 'At üstünde duruş' : 'Positioning on horse'},
      {'id': 'tactics', 'name': locale == 'tr' ? 'Taktik' : 'Tactics', 'emoji': '📋', 'desc': locale == 'tr' ? 'Yarış stratejisi' : 'Race strategy'},
      {'id': 'control', 'name': locale == 'tr' ? 'Kontrol' : 'Control', 'emoji': '🎮', 'desc': locale == 'tr' ? 'Atı yönlendirme' : 'Steering the horse'},
      {'id': 'condition', 'name': locale == 'tr' ? 'Kondisyon' : 'Condition', 'emoji': '🔋', 'desc': locale == 'tr' ? 'Fiziksel dayanıklılık' : 'Physical stamina'},
      {'id': 'motivation', 'name': locale == 'tr' ? 'Motivasyon' : 'Motivation', 'emoji': '🔥', 'desc': locale == 'tr' ? 'Kazanma arzusu' : 'Desire to win'},
    ];

    final sortedJockeys = List<JockeyAsset>.from(gameState.jockeys)
      ..sort((a, b) => a.associatedLeagueTier.compareTo(b.associatedLeagueTier));
    final selectedJockey = sortedJockeys[_selectedJockeyIndex];
    final bool isSelectedJockeyUnlocked = selectedJockey.currentStars > 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Standard & Rare Parts Panel ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Left: Standard Part (blue)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'STANDARD PART',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showProbabilityInfoDialog(isHorse: false, isRare: false),
                              child: const Padding(padding: EdgeInsets.only(left: 2.0), child: Text('ℹ️', style: TextStyle(fontSize: 11))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(locale == 'tr' ? 'Aç X1' : 'Open X1', style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 32, width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: gameState.tickets >= 1 ? () {
                                        final r = notifier.openStandardJockeyChest1xTicket();
                                        if (r != null) _showLootboxResultDialog(r);
                                      } : null,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.3), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                                      child: const Text('1 🎫', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(locale == 'tr' ? 'Aç X10' : 'Open X10', style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 32, width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: gameState.diamonds >= 100 ? () {
                                        final r = notifier.openStandardJockeyChest10xDiamonds();
                                        if (r != null) _showLootboxResultDialog(r);
                                      } : null,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.3), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                                      child: const Text('100 💎', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Right: Rare Part (purple)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF7E22CE), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'RARE PART',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF581C87)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showProbabilityInfoDialog(isHorse: false, isRare: true),
                              child: const Padding(padding: EdgeInsets.only(left: 2.0), child: Text('ℹ️', style: TextStyle(fontSize: 11))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(locale == 'tr' ? 'Aç X1' : 'Open X1', style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF581C87))),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 32, width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: gameState.diamonds >= 50 ? () {
                                        final r = notifier.openNadirJockeyChest1xDiamonds();
                                        if (r != null) _showLootboxResultDialog(r);
                                      } : null,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF581C87), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF581C87).withValues(alpha: 0.3), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                                      child: const Text('50 💎', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(locale == 'tr' ? 'Aç X10' : 'Open X10', style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF581C87))),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 32, width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: gameState.diamonds >= 500 ? () {
                                        final r = notifier.openNadirJockeyChest10xDiamonds();
                                        if (r != null) _showLootboxResultDialog(r);
                                      } : null,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF581C87), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF581C87).withValues(alpha: 0.3), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                                      child: const Text('500 💎', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ─── 1. Header Pill Banner: JOKEY GALERİSİ ───
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF3E2C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD68F1A), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              locale == 'tr' ? 'JOKEY GALERİSİ' : 'JOCKEY GALLERY',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD700),
                letterSpacing: 0.8,
              ),
            ),
          ),

          // ─── 2. Jockey Asset Cards Carousel Grid ───
          Container(
            height: 120,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: sortedJockeys.length,
              itemBuilder: (context, index) {
                final jockey = sortedJockeys[index];
                final mainIndex = index;
                final bool isSelected = _selectedJockeyIndex == mainIndex;
                final bool isAssigned = jockey.id == gameState.jockeys[gameState.leagueTier].id;
                final bool isUnlocked = jockey.currentStars > 0;
                final double targetStars = index == 5 ? 6.0 : (index + 1).toDouble();
                final bool isVIP = index == 5;

                String getJockeyEmoji(int idx) {
                  const emojis = ['👨‍🌾', '🧑‍🌾', '🏇', '🏌️', '🤵', '👑'];
                  return emojis[idx % emojis.length];
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedJockeyIndex = mainIndex;
                    });
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? (isAssigned || isSelected ? const Color(0xFFFAF8F5) : Colors.white)
                          : const Color(0xFFF0EAE1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAssigned
                            ? AppTheme.mintGreen
                            : (isSelected
                                ? const Color(0xFFD68F1A)
                                : (isUnlocked ? const Color(0xFFEFE8DE) : const Color(0xFFD1C7B7))),
                        width: isSelected || isAssigned ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected || isAssigned
                          ? [
                              BoxShadow(
                                color: (isAssigned ? AppTheme.mintGreen : const Color(0xFFD68F1A)).withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Jockey Portrait Box
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isUnlocked ? AppTheme.creamBackground : const Color(0xFFE5DDD0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                getJockeyEmoji(index),
                                style: TextStyle(
                                  fontSize: 24,
                                  color: isUnlocked ? null : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              jockey.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: isUnlocked ? AppTheme.charcoalBrown : AppTheme.mutedBrown,
                              ),
                            ),
                            const SizedBox(height: 2),
                            _buildStarRow(targetStars, size: 8),
                            const SizedBox(height: 4),
                            if (isUnlocked)
                              if (isAssigned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mintGreen,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    locale == 'tr' ? 'SEÇİLİ' : 'ACTIVE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    notifier.assignJockey(jockey.id, gameState.leagueTier);
                                    setState(() {
                                      _selectedJockeyIndex = mainIndex;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.mintGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.mintGreen, width: 1),
                                    ),
                                    child: Text(
                                      locale == 'tr' ? 'SEÇ' : 'SELECT',
                                      style: const TextStyle(
                                        color: AppTheme.mintGreen,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isVIP ? '💎 1500' : (locale == 'tr' ? '🧩 ${jockey.duplicateCardCount}/5 parça' : '🧩 ${jockey.duplicateCardCount}/5 cards'),
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Locked Chains & Padlock Overlay
                        if (!isUnlocked)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('⛓️', style: TextStyle(fontSize: 16)),
                                  Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── 3. Header Pill Banner: [JOCKEY NAME] ODASI ───
          if (isSelectedJockeyUnlocked) ...[
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3E2C1E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD68F1A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${selectedJockey.name.toUpperCase()} ${locale == 'tr' ? 'ODASI' : 'ROOM'}',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD700),
                  letterSpacing: 0.6,
                ),
              ),
            ),

            // Power Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${selectedJockey.name} ${locale == 'tr' ? 'Odası' : 'Room'}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildStarRow(selectedJockey.currentStars, size: 12),
                    ],
                  ),
                  Text(
                    '${locale == 'tr' ? 'Toplam Güç' : 'Total Power'}: ${_getJockeyPower(selectedJockey)}',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.mintGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // ─── 4. Skill Upgrade 2x2 Grid Layout (Matching Horses tab!) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.map((skill) {
                  final String id = skill['id'] as String;
                  final int level = selectedJockey.skills[id] ?? 1;
                  final double cost = notifier.getJockeySkillUpgradeCost(selectedJockey.associatedLeagueTier, level, id);
                  final bool canAfford = gameState.gold >= cost;

                  final int currentSkillVal = _getSkillValue(id, level);
                  final int nextSkillVal = _getSkillValue(id, level + 1);

                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 32) / 2,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: canAfford ? AppTheme.mintGreen.withValues(alpha: 0.35) : const Color(0xFFF1EADF),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Header Inside Skill Card: Emoji Box + Skill Name & Level
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.creamBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
                                ),
                                alignment: Alignment.center,
                                child: Text(skill['emoji'] as String, style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (skill['name'] as String).toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.charcoalBrown,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${locale == 'tr' ? 'Lvl' : 'Lvl'} $level',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 9,
                                        color: AppTheme.mutedBrown,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Skill Value Transition Preview (10 -> 13)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$currentSkillVal',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoalBrown,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.mintGreen),
                              const SizedBox(width: 6),
                              Text(
                                '$nextSkillVal',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.mintGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Full Width Train Button (Matching reference image: Eğit: 🪙100)
                          SizedBox(
                            width: double.infinity,
                            height: 30,
                            child: ElevatedButton(
                              onPressed: () => _upgradeJockeySkill(_selectedJockeyIndex, id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canAfford ? AppTheme.mintGreen : const Color(0xFFEFE8DE),
                                foregroundColor: canAfford ? Colors.white : AppTheme.mutedBrown,
                                elevation: canAfford ? 1 : 0,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                '${locale == 'tr' ? 'Eğit' : 'Train'}: 🪙${_formatNumber(cost)}',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF1EADF), width: 1.5)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(selectedJockey.name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown)),
                  const SizedBox(height: 6),
                  _buildStarRow(_selectedJockeyIndex == 5 ? 6.0 : (1.0 + _selectedJockeyIndex).toDouble(), size: 16),
                  const SizedBox(height: 16),
                  if (_selectedJockeyIndex == 5) ...[
                    Text(locale == 'tr' ? 'Elmas ile Satın Al' : 'Unlock with Diamonds', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.mutedBrown)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (gameState.diamonds < 1500) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketScreen()));
                          return;
                        }
                        final success = notifier.buyPremiumJockey(5);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locale == 'tr' ? '✅ VIP Jokey Satın Alındı!' : '✅ VIP Jockey Purchased!'), backgroundColor: AppTheme.mintGreen));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
                      child: const Text('💎 1500', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    Text(locale == 'tr' ? 'Parça Toplayarak Kilidini Aç' : 'Unlock with Fragments', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.mutedBrown)),
                    const SizedBox(height: 8),
                    Container(
                      width: 220, height: 20,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            LinearProgressIndicator(value: (selectedJockey.duplicateCardCount / 5.0).clamp(0.0, 1.0), backgroundColor: Colors.transparent, valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintGreen), minHeight: 20),
                            Text('${selectedJockey.duplicateCardCount}/5', style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(height: 1, width: 50, color: Colors.black12),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text(locale == 'tr' ? 'VEYA' : 'OR', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold))),
                        Container(height: 1, width: 50, color: Colors.black12),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketScreen())); },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
                      child: Text(locale == 'tr' ? 'Parça Satın Al' : 'Buy Fragments', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  // ─── FACILITIES TAB ───
  Widget _buildFacilitiesTab(GameStateModel gameState, GameNotifier notifier) {
    final locale = ref.watch(localeProvider);
    final category = CategoryConfig.categories[gameState.leagueTier];
    final buildings = [
      {
        'id': 'training_track',
        'name': locale == 'tr' ? category.facilities['training_track']!.nameTr : category.facilities['training_track']!.nameEn,
        'emoji': category.facilities['training_track']!.emoji,
        'desc': locale == 'tr' ? category.facilities['training_track']!.descTr : category.facilities['training_track']!.descEn,
      },
      {
        'id': 'medical_center',
        'name': locale == 'tr' ? category.facilities['medical_center']!.nameTr : category.facilities['medical_center']!.nameEn,
        'emoji': category.facilities['medical_center']!.emoji,
        'desc': locale == 'tr' ? category.facilities['medical_center']!.descTr : category.facilities['medical_center']!.descEn,
      },
      {
        'id': 'feed_storage',
        'name': locale == 'tr' ? category.facilities['feed_storage']!.nameTr : category.facilities['feed_storage']!.nameEn,
        'emoji': category.facilities['feed_storage']!.emoji,
        'desc': locale == 'tr' ? category.facilities['feed_storage']!.descTr : category.facilities['feed_storage']!.descEn,
      },
      {
        'id': 'research_lab',
        'name': locale == 'tr' ? category.facilities['research_lab']!.nameTr : category.facilities['research_lab']!.nameEn,
        'emoji': category.facilities['research_lab']!.emoji,
        'desc': locale == 'tr' ? category.facilities['research_lab']!.descTr : category.facilities['research_lab']!.descEn,
      },
      {
        'id': 'luxury_stable',
        'name': locale == 'tr' ? category.facilities['luxury_stable']!.nameTr : category.facilities['luxury_stable']!.nameEn,
        'emoji': category.facilities['luxury_stable']!.emoji,
        'desc': locale == 'tr' ? category.facilities['luxury_stable']!.descTr : category.facilities['luxury_stable']!.descEn,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: buildings.length,
      itemBuilder: (context, index) {
        final b = buildings[index];
        final String id = b['id'] as String;
        final int level = gameState.buildings[id] ?? 0;
        final double cost = notifier.getUpgradeCost(id, level);
        final bool canAfford = gameState.gold >= cost;

        final bool hasVip = gameState.equippedEquipment['vip_pass'] == 'active';
        final double vipMultiplier = hasVip ? 2.0 : 1.0;
        final double boostMultiplier = gameState.boostTimeLeft > 0 ? 2.0 : 1.0;
        final double multiplier = math.pow(10.0, gameState.leagueTier) * vipMultiplier * boostMultiplier;

        double baseYieldPerLvl = 1.0;
        if (id == 'training_track') {
          baseYieldPerLvl = 1.0;
        } else if (id == 'medical_center') {
          baseYieldPerLvl = 3.5;
        } else if (id == 'feed_storage') {
          baseYieldPerLvl = 15.0;
        } else if (id == 'research_lab') {
          baseYieldPerLvl = 70.0;
        } else if (id == 'luxury_stable') {
          baseYieldPerLvl = 300.0;
        }

        double getMilestoneMult(int l) {
          if (l >= 100) return 25.0;
          if (l >= 50) return 10.0;
          if (l >= 25) return 4.0;
          if (l >= 10) return 2.0;
          return 1.0;
        }

        final double currentYield = level * baseYieldPerLvl * getMilestoneMult(level) * multiplier;
        final double nextYield = (level + 1) * baseYieldPerLvl * getMilestoneMult(level + 1) * multiplier;
        final double nextAddYield = nextYield - currentYield;

        int nextMilestoneLevel = 10;
        int nextMilestoneBonus = 2;
        if (level >= 100) {
          nextMilestoneLevel = 200;
          nextMilestoneBonus = 50;
        } else if (level >= 50) {
          nextMilestoneLevel = 100;
          nextMilestoneBonus = 25;
        } else if (level >= 25) {
          nextMilestoneLevel = 50;
          nextMilestoneBonus = 10;
        } else if (level >= 10) {
          nextMilestoneLevel = 25;
          nextMilestoneBonus = 4;
        }

        int prevMilestoneLevel = 0;
        if (level >= 100) {
          prevMilestoneLevel = 100;
        } else if (level >= 50) {
          prevMilestoneLevel = 50;
        } else if (level >= 25) {
          prevMilestoneLevel = 25;
        } else if (level >= 10) {
          prevMilestoneLevel = 10;
        }
        final double progress = ((level - prevMilestoneLevel) / (nextMilestoneLevel - prevMilestoneLevel)).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: canAfford ? AppTheme.mintGreen.withValues(alpha: 0.4) : const Color(0xFFF1EADF),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Top Main Row (Icon Avatar + Title & Progress + Upgrade Button) ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circular Avatar with overlapping Level Badge (Matching reference image)
                    SizedBox(
                      width: 54,
                      height: 58,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 0,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppTheme.creamBackground,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFD68F1A), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD68F1A).withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(b['emoji'] as String, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF332A24),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFD700), width: 1),
                              ),
                              child: Text(
                                'LV. $level',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Middle Column: Title, Progress Bar, Current Yield
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (b['name'] as String).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.charcoalBrown,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),

                          // Milestone Level Progress Bar (Matching reference image)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 8,
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFFEFE8DE),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintGreen),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Current Yield Label
                          Row(
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 2),
                              Text(
                                '${_formatNumber(currentYield)}${AppStrings.get(locale, 'passive_per_sec')}',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD68F1A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Right Side Column: Upgrade Button + Cost Subtext (Matching reference image)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => _upgradeBuilding(id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford ? AppTheme.mintGreen : const Color(0xFFEFE8DE),
                            foregroundColor: canAfford ? Colors.white : AppTheme.mutedBrown,
                            elevation: canAfford ? 2 : 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            locale == 'tr' ? 'YÜKSELT' : 'UPGRADE',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${locale == 'tr' ? 'Maliyet' : 'Cost'}: 🪙${_formatNumber(cost)}',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: canAfford ? AppTheme.mutedBrown : AppTheme.salmonPink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ─── Bottom Inset Panel (Bonus & Milestone Goal) ───
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF8F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1EADF), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Next Level Upgrade Bonus
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 4),
                          Text(
                            '${locale == 'tr' ? 'Bonus' : 'Bonus'}: ',
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, color: AppTheme.mutedBrown),
                          ),
                          Text(
                            '+🪙${_formatNumber(nextAddYield)}${AppStrings.get(locale, 'passive_per_sec')}',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),

                      // Milestone Target
                      Row(
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text(
                            '${locale == 'tr' ? 'Hedef' : 'Target'}: Lv.$nextMilestoneLevel (x$nextMilestoneBonus)',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB87A14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── MARKET TAB ───
  Widget _buildMarketTab(GameStateModel gameState, GameNotifier notifier) {
    final locale = ref.watch(localeProvider);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Lig Kasaları
        Text(
          AppStrings.get(locale, 'league_chests_title'),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            itemBuilder: (context, index) {
              final cat = CategoryConfig.categories[index];
              final String chestName = locale == 'tr'
                  ? '${cat.nameTr.split(' ')[0]} Kasası'
                  : '${cat.nameEn.split(' ')[0]} Chest';
              final bool isUnlocked = index <= gameState.leagueTier;
              final double goldCost = 1000.0 * math.pow(10.0, index);
              final int diamondCost = 3 + index * 2;
              final bool canAffordGold = gameState.gold >= goldCost;
              final bool canAffordDiamonds = gameState.diamonds >= diamondCost;

              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUnlocked ? Colors.white : const Color(0xFFEFE8DE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUnlocked ? AppTheme.mintGreen.withValues(alpha: 0.5) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 22)),
                        if (!isUnlocked)
                          const Icon(Icons.lock_rounded, size: 14, color: AppTheme.mutedBrown)
                        else
                          Text(
                            'T${index + 1}',
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.mintGreen),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? AppTheme.charcoalBrown : AppTheme.mutedBrown,
                      ),
                    ),
                    const Spacer(),
                    if (isUnlocked) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _openLeagueChest(index, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canAffordGold ? AppTheme.mintGreen : const Color(0xFFEFE8DE),
                                foregroundColor: canAffordGold ? Colors.white : AppTheme.mutedBrown,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('🪙${_formatNumber(goldCost)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _openLeagueChest(index, false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canAffordDiamonds ? const Color(0xFF5C9BD6) : const Color(0xFFEFE8DE),
                                foregroundColor: canAffordDiamonds ? Colors.white : AppTheme.mutedBrown,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('💎$diamondCost', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        AppStrings.get(locale, 'locked_chest'),
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, color: AppTheme.mutedBrown),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Kart Birleştirme
        Text(
          AppStrings.get(locale, 'card_merge_title'),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            itemBuilder: (context, index) {
              final bool isHorse = index < 6;
              final int assetIndex = isHorse ? index : index - 6;
              final String name = isHorse ? gameState.horses[assetIndex].name : gameState.jockeys[assetIndex].name;
              final int dupCount = isHorse ? gameState.horses[assetIndex].duplicateCardCount : gameState.jockeys[assetIndex].duplicateCardCount;
              final double stars = isHorse ? gameState.horses[assetIndex].currentStars : gameState.jockeys[assetIndex].currentStars;
              final bool canMerge = dupCount >= 5;

              return Container(
                width: 130,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: canMerge ? Colors.amber : const Color(0xFFF1EADF),
                    width: canMerge ? 2 : 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isHorse ? '🐴' : '🧑‍🌾', style: const TextStyle(fontSize: 14)),
                        Text(
                          '$stars★',
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (dupCount / 5.0).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppTheme.creamBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(canMerge ? Colors.amber : AppTheme.mintGreen),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$dupCount/5',
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 8, color: AppTheme.mutedBrown),
                        ),
                        ElevatedButton(
                          onPressed: canMerge ? () => _performMerge(isHorse, assetIndex) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            disabledBackgroundColor: const Color(0xFFEFE8DE),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: AppTheme.mutedBrown,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(
                            AppStrings.get(locale, 'merge_btn'),
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Ekipman Slotları
        Text(
          AppStrings.get(locale, 'gear_slots_title'),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildEquippedSlotCard('horseshoe', locale == 'tr' ? '👟 Nal' : '👟 Horseshoe', _getActiveEquipmentItem(gameState, 'horseshoe'), notifier)),
            const SizedBox(width: 8),
            Expanded(child: _buildEquippedSlotCard('whip', locale == 'tr' ? '🏇 Kırbaç' : '🏇 Whip', _getActiveEquipmentItem(gameState, 'whip'), notifier)),
            const SizedBox(width: 8),
            Expanded(child: _buildEquippedSlotCard('saddle', locale == 'tr' ? '🏆 Eyer' : '🏆 Saddle', _getActiveEquipmentItem(gameState, 'saddle'), notifier)),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.get(locale, 'equip_bag_title'),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
            ),
            Text(
              '${AppStrings.get(locale, 'total_label')} ${gameState.inventory.length}',
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.mutedBrown),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (gameState.inventory.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1EADF)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Text('🎒', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(
                  AppStrings.get(locale, 'equip_bag_empty'),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: AppTheme.mutedBrown),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.35,
            ),
            itemCount: gameState.inventory.length,
            itemBuilder: (context, index) {
              final item = gameState.inventory[index];
              Color rarityColor = Colors.grey;
              if (item.rarity == 'rare') {
                rarityColor = Colors.blue;
              } else if (item.rarity == 'epic') {
                rarityColor = Colors.purple;
              } else if (item.rarity == 'legendary') {
                rarityColor = Colors.orange;
              }

              final bool isEquipped = gameState.equippedEquipment[item.type] == item.id;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isEquipped ? rarityColor : const Color(0xFFF1EADF), width: isEquipped ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.type == 'horseshoe' ? '👟' : item.type == 'whip' ? '🏇' : '🏆',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.rarity.toUpperCase(),
                            style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: rarityColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      locale == 'tr'
                          ? '+${(item.winChanceBonus * 100).toStringAsFixed(0)}% Kazanma'
                          : '+${(item.winChanceBonus * 100).toStringAsFixed(0)}% Win',
                      style: const TextStyle(fontSize: 8.5, color: AppTheme.mutedBrown),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isEquipped)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.mintGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppStrings.get(locale, 'equipped_label'),
                              style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: AppTheme.mintGreen),
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => notifier.equipItem(item.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.mintGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(
                              AppStrings.get(locale, 'equip_btn'),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 12),

        // Premium
        Text(
          AppStrings.get(locale, 'premium_title'),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoalBrown),
        ),
        const SizedBox(height: 6),
        _buildPremiumShopCard(gameState, notifier),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEquippedSlotCard(String type, String title, EquipmentItem? item, GameNotifier notifier) {
    final locale = ref.watch(localeProvider);
    if (item == null) {
      return Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppTheme.creamBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1EADF), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, color: AppTheme.mutedBrown),
        ),
      );
    }

    Color rarityColor = Colors.grey;
    if (item.rarity == 'rare') {
      rarityColor = Colors.blue;
    } else if (item.rarity == 'epic') {
      rarityColor = Colors.purple;
    } else if (item.rarity == 'legendary') {
      rarityColor = Colors.orange;
    }

    return Container(
      height: 70,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rarityColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 9.5, fontWeight: FontWeight.bold, color: rarityColor),
          ),
          Text(
            locale == 'tr'
                ? '+${(item.winChanceBonus * 100).toStringAsFixed(0)}% Güç'
                : '+${(item.winChanceBonus * 100).toStringAsFixed(0)}% Power',
            style: const TextStyle(fontSize: 8, color: AppTheme.mutedBrown),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => notifier.unequipItem(type),
            child: Text(
              AppStrings.get(locale, 'unequip_label'),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.salmonPink),
            ),
          ),
        ],
      ),
    );
  }

  EquipmentItem? _getActiveEquipmentItem(GameStateModel gameState, String type) {
    final String? equippedId = gameState.equippedEquipment[type];
    if (equippedId == null) { return null; }
    for (final item in gameState.inventory) {
      if (item.id == equippedId) { return item; }
    }
    return null;
  }

  Widget _buildPremiumShopCard(GameStateModel gameState, GameNotifier notifier) {
    final double tradeGoldCost = 150.0 * math.pow(10.0, gameState.leagueTier);
    final bool canAffordInstaWin = gameState.diamonds >= 2;
    final bool canAffordTrade = gameState.gold >= tradeGoldCost;
    final locale = ref.watch(localeProvider);

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.get(locale, 'insta_win_title'), style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(AppStrings.get(locale, 'insta_win_desc'), style: const TextStyle(fontSize: 9.5, color: AppTheme.mutedBrown)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final success = notifier.buyInstaWin();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.get(locale, 'insta_win_success')), backgroundColor: AppTheme.mintGreen),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAffordInstaWin ? AppTheme.salmonPink : const Color(0xFFEFE8DE),
                    foregroundColor: canAffordInstaWin ? Colors.white : AppTheme.mutedBrown,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('💎2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text('🔄', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale == 'tr' ? 'Altın → Elmas Değişimi' : 'Gold → Diamond Exchange',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text('🪙${_formatNumber(tradeGoldCost)} → 💎1', style: const TextStyle(fontSize: 9.5, color: AppTheme.mutedBrown)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    notifier.tradeGoldForDiamonds();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAffordTrade ? AppTheme.mintGreen : const Color(0xFFEFE8DE),
                    foregroundColor: canAffordTrade ? Colors.white : AppTheme.mutedBrown,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(AppStrings.get(locale, 'trade_btn'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  BOTTOM TAB BAR
  // ═══════════════════════════════════════════════════
  Widget _buildBottomTabBar(GameStateModel gameState, GameNotifier notifier) {
    final locale = ref.watch(localeProvider);
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFF1EADF), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabItem(0, Icons.sports_score_rounded, AppStrings.get(locale, 'tab_derby'), gameState, notifier),
          _buildTabItem(
            1,
            Icons.home_repair_service_rounded,
            locale == 'tr'
                ? CategoryConfig.categories[gameState.leagueTier.clamp(0, 5)].asset1NameTr
                : CategoryConfig.categories[gameState.leagueTier.clamp(0, 5)].asset1NameEn,
            gameState,
            notifier,
          ),
          _buildTabItem(
            2,
            Icons.person_rounded,
            locale == 'tr'
                ? CategoryConfig.categories[gameState.leagueTier.clamp(0, 5)].asset2NameTr
                : CategoryConfig.categories[gameState.leagueTier.clamp(0, 5)].asset2NameEn,
            gameState,
            notifier,
          ),
          _buildTabItem(3, Icons.business_rounded, AppStrings.get(locale, 'tab_facilities'), gameState, notifier),
          _buildTabItem(4, Icons.shopping_cart_rounded, AppStrings.get(locale, 'tab_market'), gameState, notifier),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label, GameStateModel gameState, GameNotifier notifier) {
    final bool isSelected = gameState.currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MarketScreen()),
            );
          } else {
            notifier.setTabIndex(index);
          }
        },
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.mintGreen.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: index == 4
                    ? ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFE5A93C), Color(0xFFE25822)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 22,
                        ),
                      )
                    : Icon(
                        icon,
                        color: isSelected ? AppTheme.mintGreen : AppTheme.mutedBrown,
                        size: 22,
                      ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.charcoalBrown : AppTheme.mutedBrown,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CountdownAdDialog extends StatefulWidget {
  final String title;
  final VoidCallback onComplete;

  const CountdownAdDialog({
    super.key,
    required this.title,
    required this.onComplete,
  });

  @override
  State<CountdownAdDialog> createState() => _CountdownAdDialogState();
}

class _CountdownAdDialogState extends State<CountdownAdDialog> {
  int _secondsLeft = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer?.cancel();
        Navigator.pop(context); // Close the dialog
        widget.onComplete(); // Call the callback
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.creamBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoalBrown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _secondsLeft / 3.0,
                    strokeWidth: 6,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintGreen),
                    backgroundColor: const Color(0xFFEFE8DE),
                  ),
                ),
                Text(
                  '$_secondsLeft',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Consumer(
              builder: (context, ref, child) {
                final locale = ref.watch(localeProvider);
                return Text(
                  locale == 'tr'
                      ? 'Ödül kazanmak için reklamın bitmesi bekleniyor...'
                      : 'Waiting for the ad to finish to claim reward...',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    color: AppTheme.mutedBrown,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PulsingGoldWidget extends StatefulWidget {
  final double gold;
  const PulsingGoldWidget({super.key, required this.gold});

  @override
  State<PulsingGoldWidget> createState() => _PulsingGoldWidgetState();
}

class _PulsingGoldWidgetState extends State<PulsingGoldWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 110,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFF1EADF),
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('🪙', style: TextStyle(fontSize: 14)),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: widget.gold),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (ctx, value, child) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          AppStrings.formatGold(value),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFFB7791F),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingLiveBadge extends StatefulWidget {
  final String locale;
  const _BlinkingLiveBadge({required this.locale});

  @override
  State<_BlinkingLiveBadge> createState() => _BlinkingLiveBadgeState();
}

class _BlinkingLiveBadgeState extends State<_BlinkingLiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFEF5350).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF5350).withValues(alpha: 0.2),
              blurRadius: 4,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFEF5350),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              widget.locale == 'tr' ? 'CANLI' : 'LIVE',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xFFDC143C), // Crimson Red
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedOfflineProgressBar extends StatefulWidget {
  final double progress;
  final String durationText;
  final String maxText;

  const _AnimatedOfflineProgressBar({
    required this.progress,
    required this.durationText,
    required this.maxText,
  });

  @override
  State<_AnimatedOfflineProgressBar> createState() => _AnimatedOfflineProgressBarState();
}

class _AnimatedOfflineProgressBarState extends State<_AnimatedOfflineProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.durationText,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoalBrown,
                  ),
                ),
                Text(
                  widget.maxText,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.salmonPink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _animation.value,
                minHeight: 12,
                backgroundColor: AppTheme.creamBackground,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.mintGreen),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveBadge extends StatefulWidget {
  final String locale;
  const _LiveBadge({required this.locale});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.charcoalBrown.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.charcoalBrown.withValues(alpha: 0.1),
              blurRadius: 4,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppTheme.charcoalBrown,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              widget.locale == 'tr' ? 'CANLI' : 'LIVE',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xFFDC143C), // Crimson Red
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _LeaderboardEntry {
  final String name;
  final double points;
  final bool isPlayer;

  _LeaderboardEntry({
    required this.name,
    required this.points,
    required this.isPlayer,
  });
}

// ─── Class Progress Bar: Yerel > Bölgesel > Ulusal > Kıtasal > Dünya ───
class _ClassProgressBar extends StatelessWidget {
  final int currentIndex;
  final String locale;
  const _ClassProgressBar({required this.currentIndex, required this.locale});

  static const _activeColor = Color(0xFFE5A93C);


  @override
  Widget build(BuildContext context) {
    const emojis = ['🥉', '🥈', '🥇', '🏆', '👑'];
    final count = emojis.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? _activeColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Opacity(
              opacity: i <= currentIndex ? 1.0 : 0.30,
              child: Text(
                emojis[i],
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Season Details Dialog (Popup Overlay) ───
class _SeasonDetailsDialog extends StatelessWidget {
  final GameStateModel gameState;
  final String locale;

  const _SeasonDetailsDialog({
    required this.gameState,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    // Use player's actual horse name instead of generic "You/Sen"
    final String playerName = gameState.horses.isNotEmpty
        ? gameState.horses[gameState.leagueTier.clamp(0, gameState.horses.length - 1)].name
        : (locale == 'tr' ? 'Sen' : 'You');

    final List<_LeaderboardEntry> leaderboard = [
      _LeaderboardEntry(
        name: playerName,
        points: gameState.seasonPoints,
        isPlayer: true,
      ),
      for (int i = 0; i < gameState.rivalJockeyNames.length; i++)
        _LeaderboardEntry(
          name: gameState.rivalJockeyNames[i],
          points: i < gameState.rivalSeasonPoints.length ? gameState.rivalSeasonPoints[i] : 0.0,
          isPlayer: false,
        ),
    ];
    leaderboard.sort((a, b) => b.points.compareTo(a.points));

    return Dialog(
      backgroundColor: AppTheme.creamBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFF1EADF), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            child: Row(
              children: [
                const Icon(Icons.leaderboard_rounded, color: AppTheme.charcoalBrown, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locale == 'tr' ? 'Sezon Detayları' : 'Season Details',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoalBrown,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.mutedBrown),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Standings table
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1EADF), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(48),
                        1: FlexColumnWidth(),
                        2: FixedColumnWidth(72),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFAF6EE),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                            ),
                          ),
                          children: [
                            _dCell(locale == 'tr' ? 'Sıra' : '#', bold: true, small: true),
                            _dCell(locale == 'tr' ? 'At / Binici' : 'Horse / Jockey', bold: true, small: true),
                            _dCell(locale == 'tr' ? 'Puan' : 'Pts', bold: true, small: true, right: true),
                          ],
                        ),
                        for (int i = 0; i < leaderboard.length; i++)
                          TableRow(
                            decoration: BoxDecoration(
                              color: leaderboard[i].isPlayer
                                  ? AppTheme.softAmber.withValues(alpha: 0.15)
                                  : null,
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFFF1EADF),
                                  width: i == leaderboard.length - 1 ? 0 : 1,
                                ),
                              ),
                            ),
                            children: [
                              _dCell(i == 0 ? '🏆' : '${i + 1}', bold: leaderboard[i].isPlayer),
                              _dCell(leaderboard[i].name, bold: leaderboard[i].isPlayer),
                              _dCell(
                                leaderboard[i].points.toStringAsFixed(0),
                                bold: leaderboard[i].isPlayer,
                                right: true,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppTheme.charcoalBrown, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        locale == 'tr' ? 'Geçmiş Sezonlar' : 'Season History',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.charcoalBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1EADF), width: 1.5),
                    ),
                    child: Builder(
                      builder: (context) {


                        final filteredIndices = <int>[];
                        for (int i = 0; i < gameState.seasonHistory.length; i++) {
                          if (i < gameState.seasonClassHistory.length) {
                            final entry = gameState.seasonClassHistory[i];
                            if (entry.contains(',')) {
                              final parts = entry.split(',');
                              final tier = int.tryParse(parts[0]) ?? 0;
                              if (tier == gameState.leagueTier) {
                                filteredIndices.add(i);
                              }
                            }
                          }
                        }

                        return Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1.0),
                            1: FlexColumnWidth(1.8),
                            2: FlexColumnWidth(1.4),
                          },
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFFAF6EE),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14),
                                ),
                              ),
                              children: [
                                _dCell(locale == 'tr' ? 'Sezon' : 'Season', bold: true, small: true),
                                _dCell(locale == 'tr' ? 'Bölüm / Sınıf' : 'Division / Class', bold: true, small: true),
                                _dCell(locale == 'tr' ? 'Derece' : 'Rank', bold: true, small: true, right: true),
                              ],
                            ),
                            if (filteredIndices.isEmpty)
                              TableRow(
                                children: [
                                  _dCell('—'),
                                  _dCell(locale == 'tr' ? 'Henüz sezon tamamlanmadı' : 'No seasons completed yet'),
                                  _dCell('—', right: true),
                                ],
                              )
                            else
                              for (int k = 0; k < filteredIndices.length; k++)
                                TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: const Color(0xFFF1EADF),
                                        width: k == filteredIndices.length - 1 ? 0 : 1,
                                      ),
                                    ),
                                  ),
                                  children: (() {
                                    final i = filteredIndices[filteredIndices.length - 1 - k];
                                    final entry = gameState.seasonClassHistory[i];
                                    final parts = entry.split(',');

                                    final classIdx = int.tryParse(parts[1]) ?? 0;

                                    final classLetter = locale == 'tr'
                                        ? const ['Yerel Amatör Kupası', 'Bölgesel Profesyonel Lig', 'Ulusal Grand Prix', 'Kıtasal Şampiyona', 'Dünya Şampiyonlar Derbisi'][classIdx.clamp(0, 4)]
                                        : const ['Local Amateur Cup', 'Regional Professional League', 'National Grand Prix', 'Continental Championship', 'World Champions Derby'][classIdx.clamp(0, 4)];
                                    final displaySeasonNum = filteredIndices.length - k;
                                    return [
                                      _dCell('$displaySeasonNum'),
                                      _dCell(classLetter),
                                      gameState.seasonHistory[i] == 1
                                          ? Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _rankStr(1),
                                                      style: const TextStyle(
                                                        fontFamily: 'Outfit',
                                                        fontSize: 12,
                                                        color: AppTheme.charcoalBrown,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons.arrow_upward_rounded,
                                                      color: AppTheme.mintGreen,
                                                      size: 14,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : _dCell(
                                              _rankStr(gameState.seasonHistory[i]),
                                              right: true,
                                            ),
                                    ];
                                  })(),
                                ),
                          ],
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dCell(String text, {bool bold = false, bool right = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: small ? 11 : 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: bold ? AppTheme.charcoalBrown : AppTheme.mutedBrown,
        ),
      ),
    );
  }

  String _rankStr(int rank) {
    if (locale == 'tr') return '$rank.';
    if (rank == 1) return '1st';
    if (rank == 2) return '2nd';
    if (rank == 3) return '3rd';
    return '${rank}th';
  }
}

// ─── Gold Particle Overlay ───
class _GoldParticleOverlay extends StatefulWidget {
  final double amount;
  final VoidCallback onDone;
  const _GoldParticleOverlay({required this.amount, required this.onDone});

  @override
  State<_GoldParticleOverlay> createState() => _GoldParticleOverlayState();
}

class _GoldParticleOverlayState extends State<_GoldParticleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rand = math.Random();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(8, (_) => _Particle(_rand));
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward().whenComplete(() {
        widget.onDone();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Target: top-left gold counter area (~60, 50 from top-left)
    const target = Offset(60, 50);
    // Start: center-bottom of screen
    final start = Offset(size.width / 2, size.height * 0.65);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        return Stack(
          children: _particles.map((p) {
            final t = Curves.easeIn.transform(_ctrl.value);
            final dx = start.dx + (target.dx - start.dx) * t + p.offsetX * (1 - t) * 60;
            final dy = start.dy + (target.dy - start.dy) * t + p.offsetY * (1 - t) * 60;
            final opacity = _ctrl.value < 0.8 ? 1.0 : (1.0 - (_ctrl.value - 0.8) / 0.2);
            return Positioned(
              left: dx,
              top: dy,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: const Text('🪙', style: TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Particle {
  final double offsetX;
  final double offsetY;
  _Particle(math.Random rand)
      : offsetX = (rand.nextDouble() - 0.5) * 2,
        offsetY = (rand.nextDouble() - 0.5) * 2;
}

int _matchCapForClass(int classIdx) {
  if (classIdx == 0) return 5;
  if (classIdx == 1 || classIdx == 2) return 10;
  if (classIdx == 3) return 15;
  return 20; // S Class
}

class _LootboxRevealDialog extends ConsumerStatefulWidget {
  final dynamic result;

  const _LootboxRevealDialog({required this.result});

  @override
  ConsumerState<_LootboxRevealDialog> createState() => _LootboxRevealDialogState();
}

class _ParticleItem {
  final double angle;
  final double speed;
  final String emoji;
  final double size;

  _ParticleItem({
    required this.angle,
    required this.speed,
    required this.emoji,
    required this.size,
  });
}

class _LootboxRevealDialogState extends ConsumerState<_LootboxRevealDialog> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _shakeController;
  late AnimationController _flipController;
  late AnimationController _particlesController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _flipAnimation;

  bool _isFlipped = false;
  bool _particlesStarted = false;
  late List<Map<String, dynamic>> _drops;
  late List<_ParticleItem> _particles;

  @override
  void initState() {
    super.initState();
    _drops = widget.result is List
        ? List<Map<String, dynamic>>.from(widget.result)
        : [widget.result as Map<String, dynamic>];

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_shakeController);

    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    final rand = math.Random();
    _particles = List.generate(24, (index) {
      final angle = (index * (2 * math.pi / 24)) + (rand.nextDouble() * 0.3 - 0.15);
      final speed = 70.0 + rand.nextDouble() * 110.0;
      final emojis = ['✨', '⭐', '💎', '🌟', '💥'];
      final emoji = emojis[rand.nextInt(emojis.length)];
      final size = 10.0 + rand.nextDouble() * 14.0;
      return _ParticleItem(angle: angle, speed: speed, emoji: emoji, size: size);
    });

    _flipAnimation.addListener(() {
      if (_flipAnimation.value >= math.pi / 2 && !_isFlipped) {
        setState(() {
          _isFlipped = true;
        });
      }
      if (_flipAnimation.value >= math.pi / 2 && !_particlesStarted) {
        _particlesStarted = true;
        _particlesController.forward();
      }
    });

    _entryController.forward().then((_) {
      _shakeController.forward().then((_) {
        _flipController.forward();
      });
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shakeController.dispose();
    _flipController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final gameState = ref.watch(gameProvider);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entryController, _shakeController, _flipController, _particlesController]),
          builder: (context, child) {
            final double scale = _scaleAnimation.value;
            final double shakeProgress = _shakeAnimation.value;
            final double shakeX = shakeProgress > 0 && shakeProgress < 1
                ? math.sin(shakeProgress * 4 * math.pi) * 8.0
                : 0.0;

            return Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (_isFlipped)
                    Positioned(
                      child: Container(
                        width: 330,
                        height: 390,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.mintGreen.withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),

                  Transform.translate(
                    offset: Offset(shakeX, 0.0),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(_flipAnimation.value),
                      child: _isFlipped
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: _buildFrontCard(context, locale, gameState),
                            )
                          : _buildBackCard(),
                    ),
                  ),

                  if (_particlesStarted)
                    ..._buildParticles(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackCard() {
    return Container(
      width: 300,
      height: 360,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C251C), Color(0xFF433729)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD700), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🎁',
            style: TextStyle(fontSize: 80),
          ),
          SizedBox(height: 20),
          Text(
            'UNBOXING...',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFD700),
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '???',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontCard(BuildContext context, String locale, GameStateModel gameState) {
    return Container(
      width: 320,
      height: 380,
      decoration: BoxDecoration(
        color: AppTheme.creamBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1EADF), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            locale == 'tr' ? 'Kutudan Çıkanlar' : 'Chest Unboxed',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.charcoalBrown,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: _drops.map((drop) {
                  final int tier = drop['tier'] as int;
                  final String name = drop['name'] as String;
                  final int amount = drop['amount'] as int;
                  final double stars = 1.5 + tier * 0.5;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.mintGreen.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Text(
                          drop['type'] == 'jockey'
                              ? (tier == 0
                                  ? '🤠'
                                  : tier == 1
                                      ? '👩‍🌾'
                                      : tier == 2
                                          ? '🏎️'
                                          : tier == 3
                                              ? '🧑‍🚀'
                                              : tier == 4
                                                  ? '🦸'
                                                  : '👑')
                              : (tier == 0
                                  ? '🐴'
                                  : tier == 1
                                      ? '🐎'
                                      : tier == 2
                                          ? '🏇'
                                          : tier == 3
                                              ? '⚡'
                                              : tier == 4
                                                  ? '🌟'
                                                  : '🦄'),
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoalBrown,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _buildStarRow(stars, size: 9),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.mintGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+$amount ${locale == 'tr' ? 'Parça' : 'Frags'}',
                            style: const TextStyle(
                              color: AppTheme.mintGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ScaleTransition(
            scale: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _particlesController,
                curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack),
              ),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mintGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 1,
              ),
              child: Text(AppStrings.get(locale, 'excellent_btn')),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildParticles() {
    final progress = _particlesController.value;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    return _particles.map((p) {
      final x = math.cos(p.angle) * p.speed * progress;
      final y = math.sin(p.angle) * p.speed * progress;
      final scale = 1.3 - 0.5 * progress;
      return Positioned(
        left: 150 + x - (p.size / 2),
        top: 170 + y - (p.size / 2),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Text(
              p.emoji,
              style: TextStyle(fontSize: p.size),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStarRow(double stars, {required double size}) {
    List<Widget> starWidgets = [];
    int fullStars = stars.floor();
    bool hasHalf = (stars - fullStars) >= 0.5;
    int count = stars > 5.0 ? stars.toInt() : 5;
    for (int i = 0; i < count; i++) {
      if (i < fullStars) {
        starWidgets.add(Icon(Icons.star, color: Colors.amber, size: size));
      } else if (i == fullStars && hasHalf) {
        starWidgets.add(Icon(Icons.star_half, color: Colors.amber, size: size));
      } else {
        starWidgets.add(Icon(Icons.star_border, color: Colors.grey.shade300, size: size));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: starWidgets);
  }
}
