# CHANGELOG

## TeleVault vendored build

- Rebuilt Android `libtdjson.so` from TDLib 1.8.66 commit
  `022d60202e446ad1287b9fb68e687c8a0760788b` with NDK 28.2.13676358 and
  OpenSSL 3.5.7 LTS for 16 KB page-size compatibility.

## 0.2.2

* Bump TDLib version to 1.8.47

## 0.2.1

* Bump TDLib version to 1.8.31

## 0.2.0

* Bump TDLib version to 1.8.30

## 0.1.4

* Bump TDLib version to 1.8.1
* perf(Service): Close the receiving loop as soon as possible after calling stop

## 0.1.3

* Bump the TD Lib version to v1.7.9

## 0.1.2

* Don't sent error to error handler if there is callback, prevent getting same error twice.

## 0.1.1

* Fix error: Receive is called after Client destroy, or simultaneously from different threads

## 0.1.0

* Support ios and macos

## 0.0.1

* Initial release.
