// lib/presentation/widgets/common_widgets.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:treelens/core/constants/app_constants.dart';
import 'package:treelens/core/theme/app_theme.dart';

/// Coloured confidence badge: green / amber / red
class ConfidenceBadge extends StatelessWidget {
  final double confidence;
  final bool compact;

  const ConfidenceBadge({super.key, required this.confidence, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toStringAsFixed(1);
    Color bg;
    Color fg;
    String label;

    if (confidence >= AppConstants.highConfidence) {
      bg = AppColors.primarySurface;
      fg = AppColors.primary;
      label = compact ? '$pct%' : 'High confidence · $pct%';
    } else if (confidence >= AppConstants.mediumConfidence) {
      bg = AppColors.accentSurface;
      fg = AppColors.accent;
      label = compact ? '$pct%' : 'Medium confidence · $pct%';
    } else {
      bg = const Color(0xFFFEE2E2);
      fg = AppColors.error;
      label = compact ? '$pct%' : 'Low confidence · $pct%';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFamily: 'SpaceGrotesk',
        ),
      ),
    );
  }
}

/// CO₂ class chip: HIGH / MEDIUM / LOW with colour coding
class Co2ClassChip extends StatelessWidget {
  final String co2Class;

  const Co2ClassChip({super.key, required this.co2Class});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (co2Class) {
      case 'HIGH':
        bg = AppColors.primarySurface;
        fg = AppColors.primary;
        break;
      case 'MEDIUM':
        bg = AppColors.accentSurface;
        fg = AppColors.accent;
        break;
      default:
        bg = Theme.of(context).colorScheme.surfaceContainerHighest;
        fg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$co2Class CO₂',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
          fontFamily: 'SpaceGrotesk',
        ),
      ),
    );
  }
}

/// Single stat tile (label + value row)
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(
                unit!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Horizontal confidence bar
class ConfidenceBar extends StatelessWidget {
  final double value;   // 0.0 – 1.0
  final Color? color;

  const ConfidenceBar({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              height: 6,
              width: constraints.maxWidth * value,
              decoration: BoxDecoration(
                color: effectiveColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Full-bleed image with gradient overlay
class TreeImage extends StatelessWidget {
  final String imagePath;
  final double height;
  final BorderRadius? borderRadius;

  const TreeImage({
    super.key,
    required this.imagePath,
    this.height = 240,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    final file = File(imagePath);

    imageWidget = Image.file(
      file,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textMuted),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        children: [
          imageWidget,
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
