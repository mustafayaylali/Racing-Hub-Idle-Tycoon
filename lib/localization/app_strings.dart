import 'package:flutter/foundation.dart' show debugPrint;

/// Oyun genelinde kullanılan lokalize string haritası ve yardımcı araçlar.
class AppStrings {
  AppStrings._();

  // ─── Otantik Yarış Atı İsimleri Havuzu ───
  static const List<String> raceHorsePool = [
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

  // ─── Kompakt Sayı Formatlayıcı ───
  /// 1234 → 1.2K | 1234567 → 1.23M | 1234 → 1234
  static String formatGold(double n) {
    if (n >= 1000000000) {
      final b = n / 1000000000;
      return '${b.toStringAsFixed(b >= 10 ? 1 : 2)}B';
    }
    if (n >= 1000000) {
      final m = n / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 1 : 2)}M';
    }
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}K';
    }
    return n.toStringAsFixed(0);
  }

  // ─── String Haritası ───
  static const Map<String, Map<String, String>> _strings = {
    // ══════════════════════════════════════
    // TÜRKÇE
    // ══════════════════════════════════════
    'tr': {
      // Sekmeler
      'tab_derby': 'Derby',
      'tab_stable': 'Ahır',
      'tab_jockeys': 'Jokeyler',
      'tab_facilities': 'Tesis',
      'tab_market': 'Market',

      // HUD
      'boost_active': '2X Aktif',
      'boost_get': '2X Boost Al',
      'passive_per_sec': '/sn',
      'lang_toggle': '🇬🇧 EN',

      // Yarış Alanı
      'win_chance': 'kazanma',
      'rank_prefix': 'Anlık:',
      'form_label': 'Form:',
      'gate_prefix': 'K',
      'next_race_label': 'Sonraki:',
      'you_label': 'SEN',

      // Derby Sekmesi
      'live_commentary': 'Canlı Anlatım',
      'active_team': 'Aktif Takım',
      'season_standings': '🏆 Sezon Sıralaması',
      'your_score_prefix': 'Sen:',
      'race_count_suffix': 'yarış tamamlandı',
      'points_info': '1. → 30p | 2. → 15p | 3. → 5p',
      'you_row': '🏇 Sen',
      'rival_prefix': '🐎',

      // Lig Dialog
      'league_dialog_title': '🏟️ Lig Seçimi',
      'league_active': '✓ Aktif',
      'close': 'Kapat',

      // Ahır
      'train_btn': 'Antren',
      'locked_horse_title': 'Bu At Kilitli!',
      'locked_horse_desc': 'ligine geç ve kilidi aç.',
      'cards_label': 'Kartlar:',
      'edit_name_title': '✏️ At İsmini Düzenle',
      'edit_name_hint': 'Yeni isim gir...',
      'free_rename_notice': '✏️ İlk değişiklik ücretsiz!',
      'ad_rename_notice': '📺 İsim değiştirmek için reklam gerekli',
      'save_btn': 'Kaydet',
      'cancel_btn': 'İptal',
      'watch_ad_btn': '📺 Reklam İzle',
      'rename_success': '✅ İsim güncellendi!',
      'horse_name_label': 'At İsmi:',

      // Jokey
      'locked_jockey_title': 'Bu Jokey Kilitli!',
      'locked_jockey_desc': 'ligine geç ve kilidi aç.',

      // Tesis
      'yield_label': 'Kazanç:',
      'upgrade_btn': 'Yükselt',

      // Market
      'league_chests_title': 'Lig Kasaları',
      'card_merge_title': 'Kart Birleştirme (5\'e 1)',
      'gear_slots_title': 'Aktif Ekipman Slotları',
      'equip_bag_title': 'Ekipman Çantası',
      'equip_bag_empty': 'Ekipman çantanız boş.',
      'premium_title': 'Premium Geliştirmeler',
      'total_label': 'Toplam:',
      'merge_btn': 'Birleştir',
      'locked_chest': 'Kilitli',
      'equip_btn': 'Tak',
      'unequip_label': 'ÇIKAR',
      'equipped_label': 'TAKILI',

      // Genel
      'not_enough_gold': '🪙 Yeterli altın yok!',
      'not_enough_diamonds': '💎 Yeterli elmas yok!',
      'excellent_btn': 'Harika!',
      'continue_btn': 'Devam Et!',
      'awesome_btn': 'Mükemmel!',
      'great_btn': 'Süper!',
      'no_btn': 'Hayır',

      // Gacha
      'card_drawn_title': '🎉 KART ÇEKİLDİ! 🎉',
      'horse_type': 'At',
      'jockey_type': 'Jokey',
      'tier_label': 'Tier',
      'card_dup_note': 'Yinelenen kart ahırına eklendi!\n5 kart topla ve birleştir!',

      // Merge
      'merge_success_title': '✨ BİRLEŞTİRME BAŞARILI! ✨',
      'stars_upgraded': 'Yıldıza Yükseltildi!',

      // Terfi
      'promotion_title': '🏆 LİG YÜKSELTME! 🏆',
      'promoted_to': 'Tebrikler! Yeni liga terfi ettin:',
      'promotion_note': 'Altın kazancı 10x arttı! Yeni pistlerde başarı şansın sıfırlandı.',

      // Sezon Sonu
      'season_champion_title': '🏆 SEZON ŞAMPİYONU!',
      'season_ended_title': '🏁 Sezon Bitti',
      'new_season_btn': 'Yeni Sezon Başlat!',
      'your_points': 'Senin Puanın:',
      'current_class': 'Mevcut Sınıf:',
      'class_promoted_note': '🎉 Birinci oldun! Sınıf yükseltildi!',

      // Sponsor
      'sponsor_title': '🎌 Sponsor Ödülü!',
      'sponsor_msg': 'Sponsor bayraktarına tıkladın!\nÜcretsiz altın kazanmak için devam et.',
      'play_earn_btn': 'Oyna & Kazan',
      'sponsor_claimed': '🎌 Sponsor altını kazanıldı!',

      // Çevrimdışı
      'welcome_back_title': '🐎 Tekrar Hoş Geldin!',
      'offline_earned_label': 'Yokluğunda ahırında birikti:',
      'offline_cap_note': 'Maks. 2 saatlik çevrimdışı kazanç hesaplandı.',
      'collect_btn': 'Topla',
      'double_ad_btn': '2X Reklam İzle',
      'doubled_msg': '⚡ Kazancın iki katına çıktı!',

      // Premium
      'insta_win_title': 'Anında Kazanma Bileti',
      'insta_win_desc': 'Anlık 1. sırayı garantile!',
      'insta_win_success': '⚡ Anında Kazandın! 1. Sıra!',
      'gold_diamond_trade': 'Altın → Elmas',
      'trade_btn': 'Değiştir',

      // Canlı Anlatım
      'commentary_ready': '🏁 Hipodrom hazır! Yarış yakında başlıyor...',
      'commentary_gates_open': '🏁 Kapılar açıldı! Yarış başlıyor!',
      'commentary_leading': '⚡ ÖNDESIN! Tempoyu koru!',
      'commentary_rival_leads': 'öne geçti!',
      'commentary_finished_1st': '🏆 KAZANDIN! 1. oldun!',
      'commentary_finished_top': 'bitirdin! Harika iş!',
      'commentary_finished_low': 'bitirdin. Daha sert antren et!',

      // Ayarlar & Sıralama & Reklam
      'settings_title': 'Ayarlar',
      'settings_lang_label': 'Dil:',
      'settings_close': 'Kapat',
      'settings_sound': 'Ses Efektleri:',
      'settings_music': 'Müzik:',
      'settings_vibrate': 'Titreşim:',
      'settings_on': 'Açık',
      'settings_off': 'Kapalı',
      'promote_btn': 'Terfi Et',
      'restart_free_btn': 'Sezonu Sıfırla (Ücretsiz)',
      'promote_desc': 'Yeni Seviye / Lige terfi et.',
      'restart_desc': 'Terfi etmeden sezonu yeniden başlat.',
      'col_rank': 'Sıra',
      'col_jockey': 'Jokey',
      'col_horse': 'At',
      'col_points': 'Puan',
      'ad_playing': 'Reklam oynatılıyor... Kalan süre:',
      'ad_completed': 'Reklam tamamlandı!',
      'season_end_gold_cost': 'Ücret:',
      'not_enough_gold_promote': 'Terfi etmek için yeterli altın yok!',
      // Geliştirme İsimleri ve Açıklamaları
      'stat_speed_name': 'Hız',
      'stat_speed_desc': 'Maksimum Hız',
      'stat_acceleration_name': 'İvme',
      'stat_acceleration_desc': 'Patlama Hızı',
      'stat_stamina_name': 'Dayanıklılık',
      'stat_stamina_desc': 'Uzun Koşu',
      'stat_focus_name': 'Odak',
      'stat_focus_desc': 'Jokey Uyumu',
      'stat_temper_name': 'Sakinlik',
      'stat_temper_desc': 'Baskı Altında',
      'stat_cornering_name': 'Dönüş',
      'stat_cornering_desc': 'Viraj Hakimiyeti',
      'skill_tactics_name': 'Taktik',
      'skill_tactics_desc': 'Stratejik kararlar',
      'skill_pacing_name': 'Tempo',
      'skill_pacing_desc': 'Hız yönetimi',
      'skill_reflexes_name': 'Refleksler',
      'skill_reflexes_desc': 'Anlık tepkiler',
      'building_training_track_name': 'Otopark',
      'building_training_track_desc': 'Ziyaretçiler için park alanı',
      'building_medical_center_name': 'Antrenman Pisti',
      'building_medical_center_desc': 'Sürekli antrenman devreleri',
      'building_feed_storage_name': 'Sağlık Merkezi',
      'building_feed_storage_desc': 'Rehabilitasyon & takviye',
      'building_research_lab_name': 'Ahır',
      'building_research_lab_desc': 'Atlar için barınak',
      'building_luxury_stable_name': 'Lüks Ahır',
      'building_luxury_stable_desc': 'Birinci sınıf yaşam alanı',
      'promotion_success': '🏆 Başarıyla terfi ettin!',
      'chest_error_gold': 'Yeterli altın yok veya kasa kilitli!',
      'chest_error_diamond': 'Yeterli elmas yok veya kasa kilitli!',
      'merge_error': 'Birleştirmek için 5 yinelenen kart gerekli!',
    },

    // ══════════════════════════════════════
    // ENGLISH
    // ══════════════════════════════════════
    'en': {
      // Tabs
      'tab_derby': 'Derby',
      'tab_stable': 'Stable',
      'tab_jockeys': 'Jockeys',
      'tab_facilities': 'Facilities',
      'tab_market': 'Market',

      // HUD
      'boost_active': '2X Active',
      'boost_get': 'Get 2X Boost',
      'passive_per_sec': '/sec',
      'lang_toggle': '🇹🇷 TR',

      // Race Area
      'win_chance': 'win chance',
      'rank_prefix': 'Current:',
      'form_label': 'Form:',
      'gate_prefix': 'G',
      'next_race_label': 'Next:',
      'you_label': 'YOU',

      // Derby Tab
      'live_commentary': 'Live Commentary',
      'active_team': 'Active Team',
      'season_standings': '🏆 Season Standings',
      'your_score_prefix': 'Yours:',
      'race_count_suffix': 'races done',
      'points_info': '1st → 30p | 2nd → 15p | 3rd → 5p',
      'you_row': '🏇 You',
      'rival_prefix': '🐎',

      // League Dialog
      'league_dialog_title': '🏟️ League Selection',
      'league_active': '✓ Active',
      'close': 'Close',

      // Stable
      'train_btn': 'Train',
      'locked_horse_title': 'This Horse is Locked!',
      'locked_horse_desc': 'Promote to unlock.',
      'cards_label': 'Cards:',
      'edit_name_title': '✏️ Edit Horse Name',
      'edit_name_hint': 'Enter new name...',
      'free_rename_notice': '✏️ First rename is free!',
      'ad_rename_notice': '📺 An ad is required to rename',
      'save_btn': 'Save',
      'cancel_btn': 'Cancel',
      'watch_ad_btn': '📺 Watch Ad',
      'rename_success': '✅ Name updated!',
      'horse_name_label': 'Horse Name:',

      // Jockey
      'locked_jockey_title': 'This Jockey is Locked!',
      'locked_jockey_desc': 'Promote to unlock.',

      // Facilities
      'yield_label': 'Yield:',
      'upgrade_btn': 'Upgrade',

      // Market
      'league_chests_title': 'League Chests',
      'card_merge_title': 'Card Merge Station (5-to-1)',
      'gear_slots_title': 'Active Gear Slots',
      'equip_bag_title': 'Equipment Bag',
      'equip_bag_empty': 'Your equipment bag is empty.',
      'premium_title': 'Premium Enhancements',
      'total_label': 'Total:',
      'merge_btn': 'Merge',
      'locked_chest': 'Locked',
      'equip_btn': 'Equip',
      'unequip_label': 'UNEQUIP',
      'equipped_label': 'EQUIPPED',

      // General
      'not_enough_gold': '🪙 Not enough Gold!',
      'not_enough_diamonds': '💎 Not enough Diamonds!',
      'excellent_btn': 'Excellent!',
      'continue_btn': 'Continue!',
      'awesome_btn': 'Awesome!',
      'great_btn': 'Great!',
      'no_btn': 'No',

      // Gacha
      'card_drawn_title': '🎉 CARD DRAWN! 🎉',
      'horse_type': 'Horse',
      'jockey_type': 'Jockey',
      'tier_label': 'Tier',
      'card_dup_note': 'Duplicate card added to your stable!\nCollect 5 to merge and upgrade stars!',

      // Merge
      'merge_success_title': '✨ MERGE SUCCESSFUL! ✨',
      'stars_upgraded': 'Stars Upgraded!',

      // Promotion
      'promotion_title': '🏆 LEAGUE PROMOTION! 🏆',
      'promoted_to': 'Outstanding! You promoted to:',
      'promotion_note': 'Gold yield scaled 10x! Win difficulty reset for new tracks.',

      // Season End
      'season_champion_title': '🏆 SEASON CHAMPION!',
      'season_ended_title': '🏁 Season Ended',
      'new_season_btn': 'Start New Season!',
      'your_points': 'Your Points:',
      'current_class': 'Current Class:',
      'class_promoted_note': '🎉 You finished 1st! Class promoted!',

      // Sponsor
      'sponsor_title': '🎌 Sponsor Reward!',
      'sponsor_msg': 'You tapped the sponsor flag!\nContinue to earn free gold.',
      'play_earn_btn': 'Watch & Earn',
      'sponsor_claimed': '🎌 Sponsor gold claimed!',

      // Offline
      'welcome_back_title': '🐎 Welcome Back!',
      'offline_earned_label': 'Your stables earned while you were away:',
      'offline_cap_note': 'Max 2-hour offline earnings calculated.',
      'collect_btn': 'Collect',
      'double_ad_btn': 'Watch Ad for 2X',
      'doubled_msg': '⚡ Your earnings were doubled!',

      // Premium
      'insta_win_title': 'Insta-Win Ticket',
      'insta_win_desc': 'Instantly guarantee 1st place!',
      'insta_win_success': '⚡ You won instantly! 1st Place!',
      'gold_diamond_trade': 'Gold → Diamond',
      'trade_btn': 'Trade',

      // Live Commentary
      'commentary_ready': '🏁 Hipodrome ready! Race starting soon...',
      'commentary_gates_open': '🏁 Gates open! Race is on!',
      'commentary_leading': '⚡ YOU ARE LEADING! Keep it up!',
      'commentary_rival_leads': 'is leading!',
      'commentary_finished_1st': '🏆 YOU WON! Finished 1st!',
      'commentary_finished_top': 'finish! Great work!',
      'commentary_finished_low': 'finish. Train harder!',

      // Settings & Standings & Ad
      'settings_title': 'Settings',
      'settings_lang_label': 'Language:',
      'settings_close': 'Close',
      'settings_sound': 'Sound Effects:',
      'settings_music': 'Music:',
      'settings_vibrate': 'Vibration:',
      'settings_on': 'On',
      'settings_off': 'Off',
      'promote_btn': 'Promote',
      'restart_free_btn': 'Restart Season (Free)',
      'promote_desc': 'Promote to the next Class / League.',
      'restart_desc': 'Restart the season without promotion.',
      'col_rank': 'Rank',
      'col_jockey': 'Jockey',
      'col_horse': 'Horse',
      'col_points': 'Points',
      'ad_playing': 'Ad playing... Time remaining:',
      'ad_completed': 'Ad completed!',
      'season_end_gold_cost': 'Fee:',
      'not_enough_gold_promote': 'Not enough gold to promote!',
      // Upgrade Names and Descriptions
      'stat_speed_name': 'Speed',
      'stat_speed_desc': 'Maximum Speed',
      'stat_acceleration_name': 'Acceleration',
      'stat_acceleration_desc': 'Burst Speed',
      'stat_stamina_name': 'Stamina',
      'stat_stamina_desc': 'Long Run',
      'stat_focus_name': 'Focus',
      'stat_focus_desc': 'Jockey Synergy',
      'stat_temper_name': 'Temper',
      'stat_temper_desc': 'Under Pressure',
      'stat_cornering_name': 'Cornering',
      'stat_cornering_desc': 'Cornering Control',
      'skill_tactics_name': 'Tactics',
      'skill_tactics_desc': 'Strategic decisions',
      'skill_pacing_name': 'Pacing',
      'skill_pacing_desc': 'Speed management',
      'skill_reflexes_name': 'Reflexes',
      'skill_reflexes_desc': 'Instant reactions',
      'building_training_track_name': 'Parking Lot',
      'building_training_track_desc': 'Parking area for visitors',
      'building_medical_center_name': 'Training Track',
      'building_medical_center_desc': 'Continuous training circuits',
      'building_feed_storage_name': 'Health Center',
      'building_feed_storage_desc': 'Rehabilitation & therapy',
      'building_research_lab_name': 'Stall',
      'building_research_lab_desc': 'Shelter for horses',
      'building_luxury_stable_name': 'Luxury Stable',
      'building_luxury_stable_desc': 'Premium living space',
      'promotion_success': '🏆 Successfully promoted!',
      'chest_error_gold': 'Not enough gold or chest is locked!',
      'chest_error_diamond': 'Not enough diamonds or chest is locked!',
      'merge_error': '5 duplicate cards required to merge!',
    },
  };

  static String get(String locale, String key) {
    final result = _strings[locale]?[key];
    if (result != null) { return result; }
    final fallback = _strings['tr']?[key];
    if (fallback != null) { return fallback; }
    debugPrint('⚠️ Missing string key: $key for locale: $locale');
    return key;
  }
}
