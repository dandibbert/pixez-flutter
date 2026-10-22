import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// MingCute icons (Apache-2.0) bundled under `assets/icons/mingcute`.
///
/// The file list is produced by `tool/import_mingcute_icons.py`.
abstract final class MingCute {
  /// Material icon → MingCute name, plus whether the Material glyph already
  /// shows a filled state (favorite vs favorite_border).
  static final Map<IconData, (String, bool)> _byMaterial = {
    Icons.account_box: ('user_3', false),
    Icons.add: ('add', false),
    Icons.arrow_back: ('arrow_left', false),
    Icons.arrow_upward: ('arrow_up', false),
    Icons.arrow_downward: ('arrow_down', false),
    Icons.arrow_drop_down: ('down_small', false),
    Icons.article: ('news', false),
    Icons.block: ('forbid_circle', false),
    Icons.book: ('book_2', false),
    Icons.bookmark: ('bookmark', true),
    Icons.bookmark_border: ('bookmark', false),
    Icons.brightness_auto: ('sun', false),
    Icons.calendar_today_outlined: ('calendar', false),
    Icons.cancel: ('close_circle', false),
    Icons.check: ('check', false),
    Icons.check_circle: ('check_circle', true),
    Icons.check_circle_outline: ('check_circle', false),
    Icons.chevron_left: ('left', false),
    Icons.chevron_right: ('right', false),
    Icons.clear: ('close', false),
    Icons.close: ('close', false),
    Icons.comment: ('comment', false),
    Icons.content_paste_rounded: ('paste', false),
    Icons.copy: ('copy_2', false),
    Icons.copy_outlined: ('copy_2', false),
    Icons.date_range: ('calendar', false),
    Icons.delete: ('delete_2', false),
    Icons.delete_forever: ('delete_2', false),
    Icons.delete_outline: ('delete_2', false),
    Icons.edit: ('edit_2', false),
    Icons.email: ('mail', false),
    Icons.error: ('warning', true),
    Icons.error_outline: ('warning', false),
    Icons.expand_less: ('up', false),
    Icons.expand_more: ('down', false),
    Icons.favorite: ('heart', true),
    Icons.favorite_border: ('heart', false),
    Icons.feed: ('news', false),
    Icons.filter_alt_outlined: ('filter', false),
    Icons.folder: ('folder', false),
    Icons.folder_open: ('folder_open', false),
    Icons.folder_open_rounded: ('folder_open', false),
    Icons.format_line_spacing: ('line_height', false),
    Icons.fullscreen: ('fullscreen', false),
    Icons.fullscreen_exit: ('fullscreen_exit', false),
    Icons.headphones: ('headphone', false),
    Icons.history: ('history', false),
    Icons.home: ('home_4', false),
    Icons.image: ('pic', false),
    Icons.image_outlined: ('pic', false),
    Icons.info: ('information', true),
    Icons.info_outline: ('information', false),
    Icons.layers_outlined: ('layers', false),
    Icons.leaderboard: ('trophy', false),
    Icons.library_books: ('book_2', false),
    Icons.link: ('link', false),
    Icons.link_rounded: ('link', false),
    Icons.list: ('list_check', false),
    Icons.local_library: ('book_2', false),
    Icons.lock_outline: ('lock', false),
    Icons.menu_book_outlined: ('book_2', false),
    Icons.message: ('comment', false),
    Icons.more_horiz: ('more_1', false),
    Icons.more_vert: ('more_2', false),
    Icons.open_in_browser: ('external_link', false),
    Icons.palette: ('palette', false),
    Icons.paste: ('paste', false),
    Icons.pause: ('pause', false),
    Icons.pause_circle_filled: ('pause_circle', true),
    Icons.pause_circle_outline: ('pause_circle', false),
    Icons.people_outline: ('group', false),
    Icons.person_outline: ('user_3', false),
    Icons.photo: ('pic', false),
    Icons.photo_album: ('pic', false),
    Icons.photo_library_outlined: ('pic', false),
    Icons.play_arrow: ('play', false),
    Icons.play_circle_filled: ('play_circle', true),
    Icons.play_circle_outline: ('play_circle', false),
    Icons.refresh: ('refresh_2', false),
    Icons.refresh_outlined: ('refresh_2', false),
    Icons.remove_red_eye: ('eye_2', false),
    Icons.report: ('warning', false),
    Icons.save: ('download_2', false),
    Icons.save_alt: ('download_2', false),
    Icons.search: ('search', false),
    Icons.send: ('send_plane', false),
    Icons.settings: ('settings_3', false),
    Icons.share: ('share_2', false),
    Icons.skip_next: ('skip_forward', false),
    Icons.skip_previous: ('skip_previous', false),
    Icons.sort: ('sort_descending', false),
    Icons.star_outline: ('star', false),
    Icons.stars: ('star', true),
    Icons.stop: ('stop', false),
    Icons.tag: ('hashtag', false),
    Icons.text_fields: ('font', false),
    Icons.timelapse_rounded: ('time', false),
    Icons.translate: ('translate_2', false),
    Icons.tune: ('settings_6', false),
    Icons.undo: ('back', false),
    Icons.visibility: ('eye_2', false),
    Icons.visibility_off: ('eye_close', false),
    Icons.visibility_off_outlined: ('eye_close', false),
    Icons.volume_up_outlined: ('volume', false),
  };

  static bool has(IconData icon) => _byMaterial.containsKey(icon);

  /// Asset path for [icon], or null when it has no MingCute counterpart.
  static String? asset(IconData icon, {bool? filled}) {
    final entry = _byMaterial[icon];
    if (entry == null) return null;
    final fill = filled ?? entry.$2;
    return 'assets/icons/mingcute/${entry.$1}_${fill ? 'fill' : 'line'}.svg';
  }
}

/// An icon that shows MingCute in the watercolor style and the given Material
/// icon in the classic style (or when no MingCute counterpart exists).
///
/// [filled] picks the MingCute fill variant, used for selected and favorited
/// states; it defaults to whatever the Material glyph shows.
class WcIcon extends StatelessWidget {
  const WcIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.filled,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final bool? filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final asset = WatercolorTokens.of(context) == null
        ? null
        : MingCute.asset(icon, filled: filled);
    if (asset == null) {
      return Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
    }
    final theme = IconTheme.of(context);
    final iconSize = size ?? theme.size ?? 24;
    final iconColor = color ?? theme.color ?? const Color(0xFF000000);
    final opacity = theme.opacity ?? 1;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: SvgPicture.asset(
        asset,
        width: iconSize,
        height: iconSize,
        colorFilter: ColorFilter.mode(
          opacity < 1
              ? iconColor.withValues(alpha: iconColor.a * opacity)
              : iconColor,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
