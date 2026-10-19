/// Quiet Ledger icons — flutter_svg 从 assets/icons/ 运行时加载。
///
/// **本文件由 `plain/tool/gen_icons_abs.py` 生成，不要手改。**
/// 权威源：`plain/assets/icons/ic_*.svg`（24 grid · 描边 1.75 · currentColor）。
/// 改图标三步：`redesign-v3/_build/gen_icons.py` → `plain/tool/import_icons_to_assets.py`
/// → `plain/tool/gen_icons_abs.py`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

@immutable
class PlainIconData {
  const PlainIconData._(this.name);

  /// File stem, e.g. `ic_cat_food` → `assets/icons/ic_cat_food.svg`.
  final String name;

  String get assetPath => 'assets/icons/$name.svg';

  static const double grid = 24;

  // ── nav · 底部导航 ──
  static const PlainIconData navLedger = PlainIconData._('ic_nav_ledger');
  static const PlainIconData navReport = PlainIconData._('ic_nav_report');
  static const PlainIconData navAdd = PlainIconData._('ic_nav_add');
  static const PlainIconData navAssets = PlainIconData._('ic_nav_assets');
  static const PlainIconData navProfile = PlainIconData._('ic_nav_profile');

  // ── category · 一级分类 ──
  static const PlainIconData catFood = PlainIconData._('ic_cat_food');
  static const PlainIconData catGrocery = PlainIconData._('ic_cat_grocery');
  static const PlainIconData catDaily = PlainIconData._('ic_cat_daily');
  static const PlainIconData catTransport = PlainIconData._('ic_cat_transport');
  static const PlainIconData catHousing = PlainIconData._('ic_cat_housing');
  static const PlainIconData catTelecom = PlainIconData._('ic_cat_telecom');
  static const PlainIconData catEntertainment = PlainIconData._(
    'ic_cat_entertainment',
  );
  static const PlainIconData catMedical = PlainIconData._('ic_cat_medical');
  static const PlainIconData catStudy = PlainIconData._('ic_cat_study');
  static const PlainIconData catSocial = PlainIconData._('ic_cat_social');
  static const PlainIconData catOther = PlainIconData._('ic_cat_other');
  static const PlainIconData catClothes = PlainIconData._('ic_cat_clothes');
  static const PlainIconData catCosmetics = PlainIconData._('ic_cat_cosmetics');
  static const PlainIconData catUmbrella = PlainIconData._('ic_cat_umbrella');
  static const PlainIconData catCleaning = PlainIconData._('ic_cat_cleaning');
  static const PlainIconData catHaircut = PlainIconData._('ic_cat_haircut');
  static const PlainIconData catPet = PlainIconData._('ic_cat_pet');
  static const PlainIconData catBaby = PlainIconData._('ic_cat_baby');
  static const PlainIconData catFurniture = PlainIconData._('ic_cat_furniture');
  static const PlainIconData catCar = PlainIconData._('ic_cat_car');
  static const PlainIconData catElectricity = PlainIconData._(
    'ic_cat_electricity',
  );
  static const PlainIconData catGame = PlainIconData._('ic_cat_game');
  static const PlainIconData catSports = PlainIconData._('ic_cat_sports');
  static const PlainIconData catTravel = PlainIconData._('ic_cat_travel');
  static const PlainIconData catTv = PlainIconData._('ic_cat_tv');
  static const PlainIconData catLaptop = PlainIconData._('ic_cat_laptop');
  static const PlainIconData catPrinter = PlainIconData._('ic_cat_printer');
  static const PlainIconData catLibrary = PlainIconData._('ic_cat_library');
  static const PlainIconData catRedpacket = PlainIconData._('ic_cat_redpacket');
  static const PlainIconData catBill = PlainIconData._('ic_cat_bill');
  static const PlainIconData catPercent = PlainIconData._('ic_cat_percent');

  // ── op · 操作 ──
  static const PlainIconData back = PlainIconData._('ic_back');
  static const PlainIconData chevronRight = PlainIconData._('ic_chevron_right');
  static const PlainIconData chevronLeft = PlainIconData._('ic_chevron_left');
  static const PlainIconData chevronDown = PlainIconData._('ic_chevron_down');
  static const PlainIconData close = PlainIconData._('ic_close');
  static const PlainIconData search = PlainIconData._('ic_search');
  static const PlainIconData filter = PlainIconData._('ic_filter');
  static const PlainIconData edit = PlainIconData._('ic_edit');
  static const PlainIconData delete = PlainIconData._('ic_delete');
  static const PlainIconData check = PlainIconData._('ic_check');
  static const PlainIconData plus = PlainIconData._('ic_plus');
  static const PlainIconData minus = PlainIconData._('ic_minus');
  static const PlainIconData more = PlainIconData._('ic_more');
  static const PlainIconData moreVertical = PlainIconData._('ic_more_vertical');
  static const PlainIconData share = PlainIconData._('ic_share');
  static const PlainIconData undo = PlainIconData._('ic_undo');
  static const PlainIconData sort = PlainIconData._('ic_sort');
  static const PlainIconData dragHandle = PlainIconData._('ic_drag_handle');
  static const PlainIconData scan = PlainIconData._('ic_scan');
  static const PlainIconData chevronUp = PlainIconData._('ic_chevron_up');
  static const PlainIconData circlePlus = PlainIconData._('ic_circle_plus');
  static const PlainIconData circleMinus = PlainIconData._('ic_circle_minus');
  static const PlainIconData play = PlainIconData._('ic_play');
  static const PlainIconData listCheck = PlainIconData._('ic_list_check');
  static const PlainIconData merge = PlainIconData._('ic_merge');
  static const PlainIconData folderPlus = PlainIconData._('ic_folder_plus');
  static const PlainIconData folderMove = PlainIconData._('ic_folder_move');

  // ── status · 状态 ──
  static const PlainIconData statusSuccess = PlainIconData._(
    'ic_status_success',
  );
  static const PlainIconData statusError = PlainIconData._('ic_status_error');
  static const PlainIconData statusWarning = PlainIconData._(
    'ic_status_warning',
  );
  static const PlainIconData statusInfo = PlainIconData._('ic_status_info');
  static const PlainIconData lock = PlainIconData._('ic_lock');
  static const PlainIconData offline = PlainIconData._('ic_offline');
  static const PlainIconData empty = PlainIconData._('ic_empty');
  static const PlainIconData loading = PlainIconData._('ic_loading');
  static const PlainIconData mood = PlainIconData._('ic_mood');

  // ── entry · 记账 ──
  static const PlainIconData calendar = PlainIconData._('ic_calendar');
  static const PlainIconData account = PlainIconData._('ic_account');
  static const PlainIconData note = PlainIconData._('ic_note');
  static const PlainIconData amount = PlainIconData._('ic_amount');
  static const PlainIconData transfer = PlainIconData._('ic_transfer');
  static const PlainIconData budget = PlainIconData._('ic_budget');
  static const PlainIconData recurring = PlainIconData._('ic_recurring');
  static const PlainIconData export = PlainIconData._('ic_export');
  static const PlainIconData import = PlainIconData._('ic_import');
  static const PlainIconData attachment = PlainIconData._('ic_attachment');
  static const PlainIconData goal = PlainIconData._('ic_goal');
  static const PlainIconData receipt = PlainIconData._('ic_receipt');
  static const PlainIconData history = PlainIconData._('ic_history');

  // ── chart · 图表 ──
  static const PlainIconData chartPie = PlainIconData._('ic_chart_pie');
  static const PlainIconData chartBars = PlainIconData._('ic_chart_bars');
  static const PlainIconData chartLine = PlainIconData._('ic_chart_line');
  static const PlainIconData trendUp = PlainIconData._('ic_trend_up');
  static const PlainIconData trendDown = PlainIconData._('ic_trend_down');

  // ── ui · 通用 ──
  static const PlainIconData settings = PlainIconData._('ic_settings');
  static const PlainIconData bell = PlainIconData._('ic_bell');
  static const PlainIconData moon = PlainIconData._('ic_moon');
  static const PlainIconData sun = PlainIconData._('ic_sun');
  static const PlainIconData palette = PlainIconData._('ic_palette');
  static const PlainIconData font = PlainIconData._('ic_font');
  static const PlainIconData volume = PlainIconData._('ic_volume');
  static const PlainIconData qr = PlainIconData._('ic_qr');
  static const PlainIconData copy = PlainIconData._('ic_copy');
  static const PlainIconData star = PlainIconData._('ic_star');
  static const PlainIconData tag = PlainIconData._('ic_tag');
  static const PlainIconData shield = PlainIconData._('ic_shield');
  static const PlainIconData fingerprint = PlainIconData._('ic_fingerprint');
  static const PlainIconData storage = PlainIconData._('ic_storage');
  static const PlainIconData image = PlainIconData._('ic_image');
  static const PlainIconData camera = PlainIconData._('ic_camera');
  static const PlainIconData eye = PlainIconData._('ic_eye');
  static const PlainIconData eyeOff = PlainIconData._('ic_eye_off');
  static const PlainIconData cloud = PlainIconData._('ic_cloud');
  static const PlainIconData wallet = PlainIconData._('ic_wallet');
  static const PlainIconData card = PlainIconData._('ic_card');
  static const PlainIconData arrowUpRight = PlainIconData._(
    'ic_arrow_up_right',
  );
  static const PlainIconData arrowDownLeft = PlainIconData._(
    'ic_arrow_down_left',
  );
  static const PlainIconData gift = PlainIconData._('ic_gift');
  static const PlainIconData trophy = PlainIconData._('ic_trophy');
  static const PlainIconData flame = PlainIconData._('ic_flame');
  static const PlainIconData celebration = PlainIconData._('ic_celebration');
  static const PlainIconData cloudUpload = PlainIconData._('ic_cloud_upload');
  static const PlainIconData cloudDownload = PlainIconData._(
    'ic_cloud_download',
  );

  static const Map<String, PlainIconData> byName = {
    'ic_nav_ledger': navLedger,
    'ic_nav_report': navReport,
    'ic_nav_add': navAdd,
    'ic_nav_assets': navAssets,
    'ic_nav_profile': navProfile,
    'ic_cat_food': catFood,
    'ic_cat_grocery': catGrocery,
    'ic_cat_daily': catDaily,
    'ic_cat_transport': catTransport,
    'ic_cat_housing': catHousing,
    'ic_cat_telecom': catTelecom,
    'ic_cat_entertainment': catEntertainment,
    'ic_cat_medical': catMedical,
    'ic_cat_study': catStudy,
    'ic_cat_social': catSocial,
    'ic_cat_other': catOther,
    'ic_cat_clothes': catClothes,
    'ic_cat_cosmetics': catCosmetics,
    'ic_cat_umbrella': catUmbrella,
    'ic_cat_cleaning': catCleaning,
    'ic_cat_haircut': catHaircut,
    'ic_cat_pet': catPet,
    'ic_cat_baby': catBaby,
    'ic_cat_furniture': catFurniture,
    'ic_cat_car': catCar,
    'ic_cat_electricity': catElectricity,
    'ic_cat_game': catGame,
    'ic_cat_sports': catSports,
    'ic_cat_travel': catTravel,
    'ic_cat_tv': catTv,
    'ic_cat_laptop': catLaptop,
    'ic_cat_printer': catPrinter,
    'ic_cat_library': catLibrary,
    'ic_cat_redpacket': catRedpacket,
    'ic_cat_bill': catBill,
    'ic_cat_percent': catPercent,
    'ic_back': back,
    'ic_chevron_right': chevronRight,
    'ic_chevron_left': chevronLeft,
    'ic_chevron_down': chevronDown,
    'ic_close': close,
    'ic_search': search,
    'ic_filter': filter,
    'ic_edit': edit,
    'ic_delete': delete,
    'ic_check': check,
    'ic_plus': plus,
    'ic_minus': minus,
    'ic_more': more,
    'ic_more_vertical': moreVertical,
    'ic_share': share,
    'ic_undo': undo,
    'ic_sort': sort,
    'ic_drag_handle': dragHandle,
    'ic_scan': scan,
    'ic_chevron_up': chevronUp,
    'ic_circle_plus': circlePlus,
    'ic_circle_minus': circleMinus,
    'ic_play': play,
    'ic_list_check': listCheck,
    'ic_merge': merge,
    'ic_folder_plus': folderPlus,
    'ic_folder_move': folderMove,
    'ic_status_success': statusSuccess,
    'ic_status_error': statusError,
    'ic_status_warning': statusWarning,
    'ic_status_info': statusInfo,
    'ic_lock': lock,
    'ic_offline': offline,
    'ic_empty': empty,
    'ic_loading': loading,
    'ic_mood': mood,
    'ic_calendar': calendar,
    'ic_account': account,
    'ic_note': note,
    'ic_amount': amount,
    'ic_transfer': transfer,
    'ic_budget': budget,
    'ic_recurring': recurring,
    'ic_export': export,
    'ic_import': import,
    'ic_attachment': attachment,
    'ic_goal': goal,
    'ic_receipt': receipt,
    'ic_history': history,
    'ic_chart_pie': chartPie,
    'ic_chart_bars': chartBars,
    'ic_chart_line': chartLine,
    'ic_trend_up': trendUp,
    'ic_trend_down': trendDown,
    'ic_settings': settings,
    'ic_bell': bell,
    'ic_moon': moon,
    'ic_sun': sun,
    'ic_palette': palette,
    'ic_font': font,
    'ic_volume': volume,
    'ic_qr': qr,
    'ic_copy': copy,
    'ic_star': star,
    'ic_tag': tag,
    'ic_shield': shield,
    'ic_fingerprint': fingerprint,
    'ic_storage': storage,
    'ic_image': image,
    'ic_camera': camera,
    'ic_eye': eye,
    'ic_eye_off': eyeOff,
    'ic_cloud': cloud,
    'ic_wallet': wallet,
    'ic_card': card,
    'ic_arrow_up_right': arrowUpRight,
    'ic_arrow_down_left': arrowDownLeft,
    'ic_gift': gift,
    'ic_trophy': trophy,
    'ic_flame': flame,
    'ic_celebration': celebration,
    'ic_cloud_upload': cloudUpload,
    'ic_cloud_download': cloudDownload,
  };

  static final List<PlainIconData> all = byName.values.toList(growable: false);
}

/// SVG icon from assets/icons/. Drop-in for `Icon`.
///
/// Uses flutter_svg — no custom path parsing. Color via `color` or IconTheme.
class PlainIcon extends StatelessWidget {
  const PlainIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final PlainIconData icon;

  /// 视觉尺寸。传 `null`（默认）时跟随 `IconTheme.of(context).size`，
  /// 与 `Icon` 的语义完全一致 —— 这样 `Icon(Icons.x)` 换成
  /// `PlainIcon(PlainIconData.y)` 后，在 `IconButton(iconSize: 18)` 之类的
  /// 语境里尺寸不会从 18 悄悄跳回 24。
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color? iconColor = color ?? IconTheme.of(context).color;
    final double box = size ?? IconTheme.of(context).size ?? 24;
    final Widget child = SvgPicture.asset(
      icon.assetPath,
      width: box,
      height: box,
      colorFilter: iconColor == null
          ? null
          : ColorFilter.mode(iconColor, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox(width: box, height: box),
    );
    if (semanticLabel != null) {
      return Semantics(label: semanticLabel, child: child);
    }
    return child;
  }
}
