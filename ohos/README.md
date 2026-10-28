# HarmonyOS Flutter toolchain setup

This module uses the `@ohos/flutter_ohos` embedding from the HarmonyOS Flutter
SDK. Copy that SDK's `flutter.har` into `ohos/libs/flutter.har` before building
the consuming HarmonyOS application. The SDK artifact is intentionally not
included in this package because it must match the consuming application's
HarmonyOS Flutter toolchain.

DuoFlex reads fold state and crease bounds from the public HarmonyOS display
APIs. Hinge angle and Flutter-view safe-area data are not exposed by this
implementation. Use Flutter constraints and `MediaQuery` for app layout.
