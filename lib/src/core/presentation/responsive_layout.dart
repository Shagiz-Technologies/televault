import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppResponsive {
  static const double maxFormWidth = 460;
  static const double maxWideContentWidth = 960;
  static const double minTouchTarget = 48;
  static const double defaultButtonHeight = 54;

  static bool isCompactHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height < 560;
  }

  static bool isNarrow(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 420;
  }

  static double gap(BuildContext context, double regular, {double? compact}) {
    if (isCompactHeight(context)) return compact ?? regular * 0.55;
    return regular;
  }

  static double iconSize(
    BuildContext context, {
    double regular = 72,
    double compact = 48,
  }) {
    return isCompactHeight(context) ? compact : regular;
  }

  static double buttonHeight(BuildContext context) {
    return math.max(
      minTouchTarget,
      isCompactHeight(context) ? 50 : defaultButtonHeight,
    );
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final compact = isCompactHeight(context);
    final narrow = isNarrow(context);
    return EdgeInsets.symmetric(
      horizontal: narrow ? 18 : 24,
      vertical: compact ? 12 : 24,
    );
  }

  static double bottomSafeGap(BuildContext context, {double extra = 16}) {
    return MediaQuery.paddingOf(context).bottom + extra;
  }

  static EdgeInsets pagePaddingWithBottomSafe(
    BuildContext context, {
    double horizontal = 16,
    double top = 16,
    double bottomExtra = 16,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      bottomSafeGap(context, extra: bottomExtra),
    );
  }
}

class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool centerVertically;
  final EdgeInsets? padding;

  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = AppResponsive.maxFormWidth,
    this.centerVertically = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final resolvedPadding = padding ?? AppResponsive.pagePadding(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minHeight = centerVertically
              ? math.max(0.0, constraints.maxHeight - resolvedPadding.vertical)
              : 0.0;

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: resolvedPadding.copyWith(
              bottom: resolvedPadding.bottom + viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
