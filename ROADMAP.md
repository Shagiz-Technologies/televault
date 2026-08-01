# Roadmap

This roadmap is intentionally conservative. TeleVault handles private media and account data, so correctness and privacy come before feature volume.

## P0 - Release safety

- Run the documented TDLib provenance and 16 KB checks for every release candidate.
- Validate each release candidate on a physical 16 KB Android device when available.
- Validate Android selected-media access on the Play review device matrix.
- Add a Play Store release checklist.
- Improve automated tests around login, sync, vault, and metadata restore.

## P1 - Product readiness

- Polish full media restore UX.
- Add clearer privacy transparency in app settings.
- Improve upload progress and retry visibility.
- Expand accessibility testing.

## P2 - Future work

- Evaluate encrypted local database metadata at rest.
- Consider all-media client-side encryption as an optional mode.
- Add richer album and label management.
- Prepare iOS support after Android stability gates pass.
