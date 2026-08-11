import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Основная кнопка с оранжевым градиентом.
class AppPrimaryButton extends StatefulWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    final child = AnimatedScale(
      scale: _pressed && enabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: widget.expand ? 12 : 20,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.gradientAccent : null,
          color: enabled ? null : AppColors.surfaceInset,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: _ButtonLabelRow(
          expand: widget.expand,
          loading: widget.loading,
          icon: widget.icon,
          label: widget.label,
          iconColor: Colors.white,
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: widget.expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

/// Вторичная кнопка с обводкой.
class AppSecondaryButton extends StatefulWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  State<AppSecondaryButton> createState() => _AppSecondaryButtonState();
}

class _AppSecondaryButtonState extends State<AppSecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    final child = AnimatedScale(
      scale: _pressed && enabled ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: widget.expand ? 12 : 18,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: _pressed && enabled
              ? AppColors.surfaceInset
              : AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? AppColors.border : AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: _ButtonLabelRow(
          expand: widget.expand,
          icon: widget.icon,
          label: widget.label,
          iconColor: enabled ? AppColors.textSecondary : AppColors.textMuted,
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: widget.expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

class _ButtonLabelRow extends StatelessWidget {
  const _ButtonLabelRow({
    required this.expand,
    required this.label,
    required this.textStyle,
    this.loading = false,
    this.icon,
    this.iconColor,
  });

  final bool expand;
  final bool loading;
  final IconData? icon;
  final String label;
  final Color? iconColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
          ],
          if (expand)
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textStyle,
              ),
            )
          else
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textStyle,
            ),
        ],
      ],
    );
  }
}

/// Круглая FAB в стиле макета.
class AppGlassFab extends StatelessWidget {
  const AppGlassFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: AppColors.accent, size: 22),
          ),
        ),
      ),
    );
  }
}
