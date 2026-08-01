# Photo and Video Permission Declaration

## Core use

TeleVault is an Android gallery, continuous media backup manager, and private
vault. Its primary function is to discover photos and videos in shared media
storage and back newly added items up to private Telegram channels controlled
by the signed-in user.

The production manifest requests:

- `READ_MEDIA_IMAGES` for continuous image discovery on Android 13+.
- `READ_MEDIA_VIDEO` for continuous video discovery on Android 13+.
- `READ_MEDIA_VISUAL_USER_SELECTED` to support selected-media access and
  re-selection on Android 14+.
- `READ_EXTERNAL_STORAGE` through Android 12L/API 32 for the same core media
  discovery behavior on older supported devices.

TeleVault does not request `MANAGE_EXTERNAL_STORAGE`, media audio access,
write-external-storage access, or original media location access.

## User-facing feature mapping

| Permission use | User-facing feature |
| --- | --- |
| Enumerate accessible images/videos | Library and Albums |
| Discover newly added media | Per-bucket Auto Backup |
| Read bytes from accessible media | Telegram backup upload |
| Re-select Android 14+ media | Library limited-access banner and Settings > Media Access |
| Explain current scope | Settings > Media Access diagnostics |

Normal media is used only for the gallery, organization, vault, and backup
features the user invokes. TeleVault does not use media access for advertising,
profiling, unrelated analytics, or contact discovery.

## Why the Android Photo Picker is insufficient

The Android Photo Picker is appropriate for one-time or infrequent user-driven
selection. TeleVault must discover media created after the initial setup while
automatic backup is enabled. Picker grants do not provide unattended discovery
of future gallery items, so picker-only access would disable the product's core
continuous-backup function. TeleVault still supports Android 14 selected-media
access when users prefer a partial gallery.

With selected access, TeleVault displays and scans only currently accessible
items, labels discovery and totals as partial, and never interprets inaccessible
items as local deletion. Existing Telegram backups are not deleted.

## Declaration summary

> TeleVault is a gallery and continuous photo/video backup manager. Broad media
> access is required to discover newly created photos and videos and back them
> up automatically to private Telegram channels controlled by the user. The
> Android Photo Picker cannot provide unattended discovery of future media.
> Access is used only for Library, Albums, Vault, and backup features.

Official references:

- [Google Play Photo and Video Permissions policy](https://support.google.com/googleplay/android-developer/answer/14115180)
- [Android selected photos access](https://developer.android.com/about/versions/14/changes/partial-photo-video-access)
- [Android Photo Picker](https://developer.android.com/training/data-storage/shared/photo-picker)
