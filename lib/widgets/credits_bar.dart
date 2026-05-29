import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';

/// Bottom credits bar shown on every screen.
class CreditsBar extends StatelessWidget {
  const CreditsBar({super.key});

  static const _tiktok = 'https://www.tiktok.com/@ir.riovansroring';
  static const _instagram = 'https://www.instagram.com/ir.riovansroring/';
  static const _youtube = 'https://youtube.com/@ir.riovanroring';

  Future<void> _open(String url) async {
    // Use launchUrl directly with try/catch (never canLaunchUrl).
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently ignore — no usable handler.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  tr('created_by'),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              _SocialButton(
                icon: Icons.music_note,
                tooltip: 'TikTok',
                onTap: () => _open(_tiktok),
              ),
              _SocialButton(
                icon: Icons.camera_alt_outlined,
                tooltip: 'Instagram',
                onTap: () => _open(_instagram),
              ),
              _SocialButton(
                icon: Icons.play_circle_outline,
                tooltip: 'YouTube',
                onTap: () => _open(_youtube),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}
