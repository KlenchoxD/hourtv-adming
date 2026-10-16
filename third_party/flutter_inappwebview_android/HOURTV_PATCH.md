# HourTV build patch

Upstream: `flutter_inappwebview_android` 1.1.3 from pub.dev, Apache-2.0.
The upstream LICENSE, README and changelog are retained with the source.

Only `android/build.gradle` differs from the stable package: debug and release
ProGuard defaults use `proguard-android-optimize.txt`, compatible with the app's
Android Gradle Plugin 9.0.1. The old `proguard-android.txt` fails during Gradle
configuration. No browser/runtime code or minification settings were changed.

The package is pinned by a local dependency override to make this correction
reproducible without changing the shared Pub cache. Remove the override once
an upstream stable release with the compatible build configuration is adopted.
