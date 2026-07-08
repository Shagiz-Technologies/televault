import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/presentation/televault_logo_mark.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: const Text('About TeleVault')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Gap(20),

            // App Icon
            const TeleVaultLogoMark(size: 108),

            const Gap(20),

            const Text(
              'TeleVault',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const Gap(8),

            Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),

            const Gap(40),

            _buildInfoRow('Developer', 'Shagiz Technologies'),
            const Gap(16),
            _buildInfoRow('License', 'Open source'),

            const Gap(40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'TeleVault turns your private Telegram channels into a personal backup shelf for photos and videos. We are too broke to run a giant data warehouse, and that is good news for your privacy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
            ),

            const Gap(18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Your media stays in your Telegram space. We do not keep a copy, we do not sell a copy, and we are not training an AI model to recognize your lunch, receipts, or blurry screenshots.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
            ),

            const Gap(40),

            Text(
              '© $year ማሔር ሻላል ሓዥ ባዝ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),

            const Gap(40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
