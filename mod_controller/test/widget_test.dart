import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mod_controller/main.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return FakePlatformWebViewController(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return FakePlatformNavigationDelegate(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return FakePlatformWebViewWidget(params);
  }
}

class FakePlatformWebViewController extends PlatformWebViewController {
  FakePlatformWebViewController(PlatformWebViewControllerCreationParams params) : super.implementation(params);

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
  
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}
  
  @override
  Future<void> setBackgroundColor(Color color) async {}
  
  @override
  Future<void> setNavigationDelegate(PlatformNavigationDelegate delegate) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}

  @override
  Future<void> removeJavaScriptChannel(String javaScriptChannelName) async {}
}

class FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  FakePlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) : super.implementation(params);
  
  @override
  Future<void> setOnPageFinished(void Function(String url) onPageFinished) async {}
}

class FakePlatformWebViewWidget extends PlatformWebViewWidget {
  FakePlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) : super.implementation(params);
  
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Set test screen size to Pixel Tablet landscape/typical viewport to avoid overflows
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(const ModControllerApp());

    // Verify that our app main title is rendered
    expect(find.text('TAMPERMOD LIVE'), findsOneWidget);
  });

}

