# Roadmap

This roadmap is intentionally conservative. TeleVault handles private media and account data, so correctness and privacy come before feature volume.

## P0 - Release safety

- Verify TDLib/libtdjson native binary provenance and licensing.
- Verify Android 15+ 16 KB page-size compatibility for native libraries.
- Review Android 14+ selected photos access behavior.
- Review and minimize Android media permissions.
- Add a Play Store release checklist.
- Improve automated tests around login, sync, vault, and metadata restore.

## P1 - Product readiness

- Polish full media restore UX.
- Add clearer privacy transparency in app settings.
- Improve upload progress and retry visibility.
- Expand accessibility testing.
- Document or remove experimental Google Drive backup code.

## P2 - Future work

- Evaluate encrypted local database metadata at rest.
- Consider all-media client-side encryption as an optional mode.
- Add richer album and label management.
- Prepare iOS support after Android stability gates pass.
