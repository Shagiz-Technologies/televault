import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/config/legal_urls.dart';

void main() {
  test('legal URLs use the canonical Shagiz GitHub Pages origin', () {
    const expected = <String, String>{
      'privacy': LegalUrls.privacyPolicy,
      'terms': LegalUrls.termsOfService,
      'support': LegalUrls.support,
      'deletion': LegalUrls.dataDeletion,
      'security': LegalUrls.security,
    };

    for (final entry in expected.entries) {
      final uri = Uri.parse(entry.value);
      expect(uri.scheme, 'https', reason: entry.key);
      expect(uri.host, 'shagiz-technologies.github.io', reason: entry.key);
      expect(uri.path, startsWith('/tele-vault/'), reason: entry.key);
    }

    expect(
      LegalUrls.sourceCode,
      'https://github.com/Shagiz-Technologies/televault',
    );
  });
}
