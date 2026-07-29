# TeleVault Governance

TeleVault is maintained by Shagiz Technologies. Public contributions are accepted through pull requests; public visibility does not grant permission to push or merge into this repository.

## Branch model

- `main` is the protected, release-ready branch.
- Contributors should use focused branches such as `feature/<issue>-<description>`, `fix/<issue>-<description>`, or `docs/<description>`.
- Release branches such as `release/1.2.0` should be temporary and used only when release stabilization requires them.
- Production releases are identified by immutable semantic-version tags such as `v1.2.0`; a merge into `main` is not itself a production deployment.

## Change process

1. Open or identify an issue for non-trivial work.
2. Create a focused branch in a fork or in the repository when authorized.
3. Open a pull request targeting `main`.
4. Pass formatting, analysis, tests, and any platform-specific validation.
5. Resolve all review conversations.
6. A maintainer merges using squash merge.

Direct pushes, force pushes, and deletion of `main` should be blocked through a GitHub repository ruleset.

## Roles

- **Public contributor:** can fork the repository, open issues, and submit pull requests.
- **Triage member:** may manage issues and pull-request organization without code-write access.
- **Maintainer:** may review and merge validated changes.
- **Administrator:** manages repository settings, teams, security, and releases.

Write or administrator access is granted only after sustained, trustworthy contribution and demonstrated understanding of TeleVault's privacy, security, data-integrity, and release requirements.

## Sensitive changes

Changes affecting authentication, Telegram sessions, permissions, sync, deletion, restore, encryption, the vault, native binaries, signing, CI, or release automation require maintainer review. Security vulnerabilities must follow `SECURITY.md` and must not be disclosed in public issues.

## Releases

Releases should follow this path:

1. Merge validated changes into `main`.
2. Create a signed semantic-version tag.
3. Build the signed Android App Bundle from that tag.
4. Publish to Play Store internal testing.
5. Validate the candidate.
6. Promote the tested artifact to production.

Signing keys, keystores, Telegram credentials, Google Play credentials, and other production secrets must never be committed to Git.

## Maintainer succession

The initial code owner is `@ZelalemGizachew`. When a `televault-maintainers` organization team is created and granted Write access, `CODEOWNERS` should be updated to reference `@Shagiz-Technologies/televault-maintainers` instead of an individual account.
