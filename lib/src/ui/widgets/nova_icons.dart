import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG icons extracted directly from the Kockatoos landing page chat widget.
class NovaIcons {
  NovaIcons._();

  /// Chat FAB toggle icon from `fab.blade.php`.
  static const String fabChatSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
</svg>
''';

  /// Support agent / headset avatar icon from `template.js` and `drawer.blade.php`.
  static const String botAvatarSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M3 18v-6a9 9 0 0 1 18 0v6" />
    <path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z" />
    <path d="M14 21h-2a2 2 0 0 1-2-2v-1" />
</svg>
''';

  /// Sound ON speaker icon from `template.js` and `chat.js`.
  static const String soundOnSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M19.114 5.636a9 9 0 0 1 0 12.728M16.463 8.288a5.25 5.25 0 0 1 0 7.424M6.75 8.25l4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.009 9.009 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z" />
</svg>
''';

  /// Sound OFF (muted) speaker icon from `chat.js`.
  static const String soundOffSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M17.25 9.75 19.5 12m0 0 2.25 2.25M19.5 12l2.25-2.25M19.5 12l-2.25 2.25m-10.5-6 4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.009 9.009 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z" />
</svg>
''';

  /// New conversation / pencil compose icon from `template.js`.
  static const String newChatSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
    <path d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10" />
</svg>
''';

  /// Close drawer icon from `template.js`.
  static const String closeSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M6 18L18 6M6 6l12 12" />
</svg>
''';

  /// Renders the landing page chat FAB icon as an SVG widget.
  static Widget fabChat({
    double size = 26,
    Color color = Colors.white,
  }) {
    return SvgPicture.string(
      fabChatSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// Renders the landing page bot avatar icon as an SVG widget.
  static Widget botAvatar({
    double size = 18,
    Color color = Colors.white,
  }) {
    return SvgPicture.string(
      botAvatarSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// Renders the landing page sound ON icon as an SVG widget.
  static Widget soundOn({
    double size = 20,
    Color color = const Color(0xFF64748B),
  }) {
    return SvgPicture.string(
      soundOnSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// Renders the landing page sound OFF icon as an SVG widget.
  static Widget soundOff({
    double size = 20,
    Color color = const Color(0xFF94A3B8),
  }) {
    return SvgPicture.string(
      soundOffSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// Renders the landing page new conversation icon as an SVG widget.
  static Widget newChat({
    double size = 20,
    Color color = const Color(0xFF64748B),
  }) {
    return SvgPicture.string(
      newChatSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// Renders the landing page close drawer icon as an SVG widget.
  static Widget close({
    double size = 20,
    Color color = const Color(0xFF64748B),
  }) {
    return SvgPicture.string(
      closeSvg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
