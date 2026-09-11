import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Network avatar tuned for Flutter Web/PWA on iOS.
///
/// Prefer Flutter's normal image pipeline first. If the browser blocks that
/// path (for example because of CORS), Flutter may fall back to an HTML image
/// element. Forcing the HTML path on iOS can render a transparent platform view
/// inside clipped/sliver layouts such as the client home profile card.
class SafeNetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;
  final double? iconSize;

  const SafeNetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.backgroundColor,
    required this.iconColor,
    this.icon = Icons.person_outline_rounded,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final url = imageUrl?.trim();

    Widget fallback() => ColoredBox(
          color: backgroundColor,
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: iconSize ?? radius,
            ),
          ),
        );

    if (url == null || url.isEmpty) {
      return SizedBox(
        width: diameter,
        height: diameter,
        child: ClipOval(child: fallback()),
      );
    }

    final isIosWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: Image.network(
          url,
          key: ValueKey(url),
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          webHtmlElementStrategy: isIosWeb
              ? WebHtmlElementStrategy.fallback
              : WebHtmlElementStrategy.never,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      ),
    );
  }
}
