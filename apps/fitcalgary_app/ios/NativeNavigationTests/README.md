# Native navigation verification

This isolated Xcode UI test operates the real UIKit tab controls in the installed
FitCalgary simulator application. It does not test account/provider authentication.
Flutter gesture tests cover the fallback Flutter navigation separately.

Build/install the simulator app with `NATIVE_IOS_NAVIGATION=true` and the normal
production endpoint configuration. The revised appearance is approved and enabled
by default on supported iOS versions. Set `NATIVE_IOS_NAVIGATION=false` only to
exercise the Flutter fallback; Android and unsupported iOS versions keep it automatically.
Use an iOS 26 or later simulator. Install XcodeGen, then from the Flutter app folder:

```sh
xcodegen --spec ios/NativeNavigationTests/project.yml
xcodebuild -project ios/NativeNavigationTests/FitNavigationTests.xcodeproj \
  -scheme FitNavigationTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test
```

The generated project is not source-controlled. Screenshots are retained as
XCTest attachments. Run with a fresh result-bundle path to preserve evidence.
Do not infer physical-device, provider-login or store approval from this test.
