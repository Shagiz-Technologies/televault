# Changelog

All notable changes to TeleVault will be documented in this file.

## Unreleased

- Added explicit full, selected, denied, and permanently denied Android media
  access states with in-context permission UX and diagnostics.
- Prevented inaccessible limited-access media from being classified as deleted
  or retried continuously.
- Removed unused media-location access and the unwired Google Drive/Google
  Sign-In prototype dependencies.
- Added authenticated metadata snapshot v5 using the TeleVault Recovery Key,
  transactional restore, conservative Telegram reconciliation, and legacy-v4
  read-only migration.
- Added two-verified-snapshot remote retention, durable operation locking, stale
  local-path handling, and resumable local-account cleanup on logout/switch.
- Prepared repository for an initial open-source release.
- Added public documentation, privacy/security policy files, issue templates, and CI workflow.
- Documented current Android-first support, Telegram independence, TDLib/libtdjson use, and encryption limitations.
