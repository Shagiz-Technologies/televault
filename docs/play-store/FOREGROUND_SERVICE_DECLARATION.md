# Foreground service declaration

## Current release state

The current TeleVault production manifest does not declare an Android foreground service or a foreground-service permission. No foreground-service declaration should be submitted in Play Console for this release unless the implementation and merged manifest change.

## Required behavior if added later

A future long-running, user-initiated sync may use a visible and cancellable foreground service only when Android requires it and only while the user-beneficial transfer is active. It must:

- use the correct data-sync or user-initiated transfer mechanism for the targeted Android version;
- display an ongoing notification that clearly identifies TeleVault backup activity;
- provide a stop action;
- stop promptly when work completes, is cancelled, the user logs out, or required constraints are lost;
- never run as a silent or permanent service;
- be documented consistently in the manifest, Play Console declaration, Privacy Policy, and review video.

## Release check

Inspect the merged manifest from the final AAB. If any `FOREGROUND_SERVICE` permission, `foregroundServiceType`, service component, or long-running worker notification is present, replace this document with an exact declaration matching the implementation before submission.
