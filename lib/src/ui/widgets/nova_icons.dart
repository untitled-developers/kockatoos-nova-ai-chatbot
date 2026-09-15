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

  /// Renders the landing page chat FAB icon as an SVG widget.
  static Widget fabChat({
    double size = 10,
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
}
