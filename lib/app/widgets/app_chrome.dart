import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color = AppColors.card,
    this.borderColor = AppColors.line,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final shape = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: BorderSide(color: borderColor),
    );
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}

class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isFilled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isFilled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: isFilled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isFilled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
