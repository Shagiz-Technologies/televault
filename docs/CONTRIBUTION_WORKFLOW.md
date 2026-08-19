# Contribution Workflow

TeleVault uses maintainer-controlled pull requests:

```text
Issue
-> maintainer agreement for major work
-> contributor fork
-> focused branch
-> implementation and tests
-> pull request to main
-> CI
-> maintainer review
-> contributor revisions
-> squash merge
```

## 1. Start with an issue

Use the structured issue forms. A maintainer must agree on direction before
work begins when a proposal affects architecture, Android permissions,
encryption, Telegram login or sessions, synchronization, restore, storage
formats, native binaries, dependencies, signing, or release automation.

Maintainer agreement to investigate is not a promise to merge a particular
implementation.

## 2. Work from a fork

Public contributors should fork the repository, synchronize their fork with the
latest `main`, and create one focused branch. Do not mix unrelated generated
files, formatting, dependency changes, or local configuration into the branch.

## 3. Validate locally

Follow [`DEVELOPMENT.md`](../DEVELOPMENT.md). Include tests for behavior changes
and sanitized screenshots for UI changes. Never include credentials, Telegram
sessions, user media, local databases, metadata backups, signing material, or
unredacted logs.

## 4. Open a pull request

Target `main` and complete the active pull-request template. CI must pass and
all review conversations must be resolved. Maintainers may request a smaller
scope, migration notes, privacy analysis, Android device evidence, or a
different implementation.

## 5. Review and merge

Public contributors cannot merge their own pull requests. A maintainer reviews
the code, privacy and security boundaries, tests, and release impact. Accepted
changes use squash merge so `main` retains linear history. Merging a pull
request does not automatically create a production release.
