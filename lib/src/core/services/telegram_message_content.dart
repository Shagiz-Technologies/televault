class TelegramMessageContent {
  const TelegramMessageContent._();

  // TDLib 1.8.66 wraps InputFile in inputDocument/inputPhoto/inputVideo.

  static Map<String, dynamic> localFile(String path) => {
    '@type': 'inputFileLocal',
    'path': path,
  };

  static Map<String, dynamic> document({
    required Map<String, dynamic> file,
    required String caption,
    bool preserveAsFile = true,
  }) => {
    '@type': 'inputMessageDocument',
    'document': {
      '@type': 'inputDocument',
      'document': file,
      'thumbnail': null,
      'disable_content_type_detection': preserveAsFile,
    },
    'caption': _caption(caption),
  };

  static Map<String, dynamic> photo({
    required Map<String, dynamic> file,
    required String caption,
  }) => {
    '@type': 'inputMessagePhoto',
    'photo': {
      '@type': 'inputPhoto',
      'photo': file,
      'thumbnail': null,
      'video': null,
      'added_sticker_file_ids': <int>[],
      'width': 0,
      'height': 0,
    },
    'caption': _caption(caption),
    'show_caption_above_media': false,
    'self_destruct_type': null,
    'has_spoiler': false,
  };

  static Map<String, dynamic> video({
    required Map<String, dynamic> file,
    required String caption,
  }) => {
    '@type': 'inputMessageVideo',
    'video': {
      '@type': 'inputVideo',
      'video': file,
      'thumbnail': null,
      'cover': null,
      'start_timestamp': 0,
      'added_sticker_file_ids': <int>[],
      'duration': 0,
      'width': 0,
      'height': 0,
      'supports_streaming': true,
    },
    'caption': _caption(caption),
    'show_caption_above_media': false,
    'self_destruct_type': null,
    'has_spoiler': false,
  };

  static Map<String, dynamic> _caption(String text) => {
    '@type': 'formattedText',
    'text': text,
    'entities': <Map<String, dynamic>>[],
  };
}
