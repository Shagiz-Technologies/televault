# Google Play app access

Status: **reviewer access is included in the same production AAB; verify it on the exact signed release before submission.**

TeleVault requires Telegram authorization before its main backup features are available. The production AAB therefore provides a pre-login `Google Play reviewer access` action that selects Telegram's Test DC before TDLib or any account-scoped TeleVault service starts.

## Runtime isolation

Normal startup remains the default and uses Telegram Production DC plus the existing production storage names.

Reviewer access:

- sets TDLib `use_test_dc` to `true`;
- uses the same build-time `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` as normal startup;
- uses separate TDLib, Drift, cache, Vault, secure-storage, WorkManager, metadata-temporary, and cleanup-marker namespaces;
- shows a persistent `Telegram Test Environment` banner;
- rejects worker wake-ups from another runtime namespace;
- never opens, clears, or modifies production sessions or local data.

No phone number, login code, Telegram session, API credential, private media, or reviewer identity is hardcoded in the app. The older `TELEVAULT_PLAY_REVIEW=true` switch remains available only for development builds; it is not required for Play review.

## Reviewer steps

1. Install and launch the normal signed TeleVault AAB delivered by Google Play.
2. On the first connection screen, select **Google Play reviewer access**.
3. Confirm that the persistent **Telegram Test Environment** banner is visible.
4. Enter a Telegram Test DC phone number in the `99966XYYYY` format, where `X` is Test DC `1`, `2`, or `3`, and `YYYY` is any available four-digit suffix.
5. Enter the reusable verification code `XXXXX`, where every `X` is the same Test DC number used in the phone number.
6. Complete the normal TeleVault onboarding and grant the photo/video access needed for the test.
7. Create a private test bucket and upload test media.
8. Confirm the item reaches `Synced` only after the test channel receives it.
9. Confirm Terms and Privacy remain readable from the pre-login flow.
10. Use **Return to normal Telegram** when finished. Confirm Test Environment state is removed and normal TeleVault data is unchanged.

Use only non-sensitive test media and messages. Telegram documents that these
synthetic test accounts can be used by others and may be periodically cleared.

## Play Console instructions

Copy the reviewer steps above into Play Console App access. State explicitly that the number and code use Telegram's synthetic Test DC format and do not belong to a real person. Do not provide a personal production Telegram account or an unpredictable production OTP.

## Submission blockers

Do not submit until:

- the exact signed production AAB has completed this Test DC flow;
- the banner remains visible throughout the reviewer session;
- a test bucket and test-media upload succeed;
- returning to production has been verified not to remove production data;
- Play-generated APKs have been tested after bundle processing.
