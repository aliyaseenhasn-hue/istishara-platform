import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Network avatar that avoids the CanvasKit image-texture path on iOS Web/PWA.
///
/// Flutter Web on iOS can occasionally render network-image textures as black
/// after route/sliver transitions. Using an HTML image element there keeps the
/// avatar outside that WebGL texture path while preserving the normal image
/// pipeline on Android, iOS native, and desktop web.
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

    final useHtmlImage =
        kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: Image.network(
          url,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          webHtmlElementStrategy: useHtmlImage
              ? WebHtmlElementStrategy.prefer
              : WebHtmlElementStrategy.never,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      ),
    );
  }
}
