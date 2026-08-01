import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final driveBackupServiceProvider = Provider<DriveBackupService>((ref) {
  return DriveBackupService();
});

class DriveBackupService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  static const _backupFilename = 'tele_vault_backup.sqlite';
  static const _localDbFilename = 'tele_vault.sqlite';

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (_) {
      debugPrint('Google Drive sign-in did not complete.');
      return null;
    }
  }

  Future<void> uploadDatabase() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      debugPrint('Not authenticated');
      return;
    }

    final driveApi = drive.DriveApi(client);
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, _localDbFilename);
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      debugPrint('The local metadata database was not found.');
      return;
    }

    final media = drive.Media(dbFile.openRead(), await dbFile.length());
    final driveFile = drive.File()..name = _backupFilename;

    await driveApi.files.create(driveFile, uploadMedia: media);
    debugPrint('Database backed up to Google Drive');
  }

  Future<void> restoreDatabase() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return;

    final driveApi = drive.DriveApi(client);
    final fileList = await driveApi.files.list(
      q: "name = '$_backupFilename' and trashed = false",
      $fields: 'files(id, name)',
    );

    if (fileList.files?.isEmpty ?? true) {
      debugPrint('No backup found');
      return;
    }

    final fileId = fileList.files!.first.id!;
    final media =
        await driveApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, _localDbFilename);
    final saveFile = File(dbPath);

    final sink = saveFile.openWrite();
    await media.stream.pipe(sink);
    await sink.close();

    debugPrint('Database restored, restart app');
  }
}
