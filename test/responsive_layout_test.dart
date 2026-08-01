import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/presentation/responsive_layout.dart';

void main() {
  testWidgets('bottom safe gap honors edge-to-edge view padding', (
    tester,
  ) async {
    double? measuredGap;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.only(bottom: 32),
          systemGestureInsets: EdgeInsets.only(bottom: 20),
        ),
        child: Builder(
          builder: (context) {
            measuredGap = AppResponsive.bottomSafeGap(context, extra: 5);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(measuredGap, 37);
  });
}
