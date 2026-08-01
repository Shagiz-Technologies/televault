import 'package:flutter_test/flutter_test.dart';
import 'package:tele_vault/src/core/services/telegram_message_content.dart';

void main() {
  const path = '/safe/test/media.jpg';
  final inputFile = TelegramMessageContent.localFile(path);

  test('document payload wraps InputFile for TDLib 1.8.66', () {
    final content = TelegramMessageContent.document(
      file: inputFile,
      caption: 'Backup',
    );
    final document = content['document'] as Map<String, dynamic>;

    expect(content['@type'], 'inputMessageDocument');
    expect(document['@type'], 'inputDocument');
    expect(document['document'], inputFile);
    expect(document['disable_content_type_detection'], isTrue);
    expect(_entities(content), isEmpty);
  });

  test('photo payload wraps InputFile for TDLib 1.8.66', () {
    final content = TelegramMessageContent.photo(
      file: inputFile,
      caption: 'Backup',
    );
    final photo = content['photo'] as Map<String, dynamic>;

    expect(content['@type'], 'inputMessagePhoto');
    expect(photo['@type'], 'inputPhoto');
    expect(photo['photo'], inputFile);
    expect(content['has_spoiler'], isFalse);
    expect(_entities(content), isEmpty);
  });

  test('video payload wraps InputFile for TDLib 1.8.66', () {
    final content = TelegramMessageContent.video(
      file: inputFile,
      caption: 'Backup',
    );
    final video = content['video'] as Map<String, dynamic>;

    expect(content['@type'], 'inputMessageVideo');
    expect(video['@type'], 'inputVideo');
    expect(video['video'], inputFile);
    expect(video['supports_streaming'], isTrue);
    expect(_entities(content), isEmpty);
  });
}

List<dynamic> _entities(Map<String, dynamic> content) {
  final caption = content['caption'] as Map<String, dynamic>;
  return caption['entities'] as List<dynamic>;
}
