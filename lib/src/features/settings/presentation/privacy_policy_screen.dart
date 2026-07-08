import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TeleVault Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: $year',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 24),

            _buildSection(
              'The Short Version',
              'Your photos and videos go to your own private Telegram channels. We do not run a secret server full of your selfies. Honestly, we are too broke for that infrastructure, and your privacy benefits from our budget situation.',
            ),

            _buildSection(
              'What We Collect',
              'TeleVault keeps local metadata on your device so it can remember what is pending, uploaded, failed, vaulted, or restored. Your actual media is not collected by us. It is backed up to Telegram storage that belongs to your account.',
            ),

            _buildSection(
              'What We Do Not Do',
              'We do not sell your data. We do not rent it. We do not feed it to an AI model and call it innovation. We are not one of those companies casually training models on your private memories while smiling in a policy document.',
            ),

            _buildSection(
              'Telegram Storage',
              'TeleVault uses Telegram TDLib to talk to Telegram. Your backups live in private Telegram channels controlled by your Telegram account. Telegram is the storage provider; TeleVault is the tool that organizes the backup flow.',
            ),

            _buildSection(
              'Vault Security',
              'Vault items are encrypted before upload. Your Vault PIN or password is stored as a salted hash on-device, not as plain text. Phone Security can be used to unlock or reset access when configured.',
            ),

            _buildSection(
              'Your Control',
              'You can delete local metadata, remove backed-up items, change buckets, export metadata, or stop using the app. If you uninstall without a Safe Uninstall backup, Android may remove local app data, because Android does not care about our feelings.',
            ),

            const SizedBox(height: 40),

            Center(
              child: Text(
                '© $year ማሔር ሻላል ሓዥ ባዝ',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[300],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
