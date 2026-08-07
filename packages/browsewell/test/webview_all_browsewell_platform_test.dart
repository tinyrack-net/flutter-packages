import 'package:browsewell/browsewell.dart';
import 'package:browsewell/src/webview_all_browsewell_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WebViewPlatform? original;
  late _FakeWebViewPlatform webviews;
  late WebviewAllBrowsewellPlatform platform;
  final nativeCalls = <MethodCall>[];

  setUp(() {
    original = WebViewPlatform.instance;
    webviews = _FakeWebViewPlatform();
    WebViewPlatform.instance = webviews;
    platform = WebviewAllBrowsewellPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('net.tinyrack.browsewell/automation'),
          (call) async {
            nativeCalls.add(call);
            if (call.method == 'screenshot') {
              return Uint8List.fromList(<int>[137, 80, 78, 71]);
            }
            return null;
          },
        );
  });

  tearDown(() {
    if (original != null) WebViewPlatform.instance = original;
    nativeCalls.clear();
  });

  testWidgets('drives renderer navigation, events, logs, and native input', (
    tester,
  ) async {
    final created = await platform.create(
      BrowsewellCreateRequest(
        profile: const BrowsewellProfile(directory: '/profile'),
        initialUrl: Uri.parse('https://example.test'),
        policy: const BrowsewellPolicy(),
      ),
    );
    final id = created.id;
    final events = <BrowsewellEvent>[];
    final subscription = platform.events(id).listen(events.add);
    addTearDown(subscription.cancel);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: platform.buildView(id),
      ),
    );
    expect(find.byType(SizedBox), findsOneWidget);

    webviews.delegate.onPageStarted?.call('https://example.test/start');
    webviews.delegate.onPageFinished?.call('https://example.test/end');
    await tester.pump();
    webviews.controller.console?.call(
      const JavaScriptConsoleMessage(
        level: JavaScriptLogLevel.info,
        message: 'ready',
      ),
    );
    await webviews.controller.alert?.call(
      const JavaScriptAlertDialogRequest(
        message: 'alert',
        url: 'https://example.test',
      ),
    );
    expect(
      await webviews.controller.confirm?.call(
        const JavaScriptConfirmDialogRequest(
          message: 'confirm',
          url: 'https://example.test',
        ),
      ),
      isFalse,
    );
    expect(
      await webviews.controller.prompt?.call(
        const JavaScriptTextInputDialogRequest(
          message: 'prompt',
          url: 'https://example.test',
          defaultText: 'default',
        ),
      ),
      isEmpty,
    );
    expect(events.map((event) => event.type), <String>['loadStart', 'loadEnd']);

    await platform.execute(
      id,
      const BrowsewellCommand('navigate', <String, Object?>{
        'url': 'https://example.test/next',
      }),
    );
    for (final name in <String>['back', 'forward', 'reload', 'resize']) {
      await platform.execute(
        id,
        BrowsewellCommand(
          name,
          name == 'resize'
              ? const <String, Object?>{'width': 320.0, 'height': 240.0}
              : const <String, Object?>{},
        ),
      );
    }
    await tester.pump();
    expect(
      tester.getSize(find.byKey(ValueKey<String>('$id-viewport'))),
      const Size(320, 240),
    );
    expect(
      await platform.execute(id, const BrowsewellCommand('snapshot')),
      isA<Map<Object?, Object?>>(),
    );
    expect(
      await platform.execute(
        id,
        const BrowsewellCommand('screenshot', <String, Object?>{
          'fullPage': true,
        }),
      ),
      isA<Uint8List>(),
    );
    expect(
      await platform.execute(
        id,
        const BrowsewellCommand('logs', <String, Object?>{'maxEntries': 1}),
      ),
      hasLength(1),
    );
    await platform.execute(
      id,
      const BrowsewellCommand('wait', <String, Object?>{
        'text': 'Ready',
        'timeoutMs': 100,
      }),
    );

    for (final command in <BrowsewellCommand>[
      const BrowsewellCommand('click', <String, Object?>{'ref': '@1:1'}),
      const BrowsewellCommand('hover', <String, Object?>{'ref': '@1:1'}),
      const BrowsewellCommand('fill', <String, Object?>{
        'ref': '@1:1',
        'value': 'Ada',
      }),
      const BrowsewellCommand('type', <String, Object?>{
        'ref': '@1:1',
        'text': ' Lovelace',
      }),
      const BrowsewellCommand('keypress', <String, Object?>{
        'ref': '@1:1',
        'key': 'Enter',
      }),
      const BrowsewellCommand('select', <String, Object?>{
        'ref': '@1:1',
        'value': 'two',
      }),
      const BrowsewellCommand('drag', <String, Object?>{
        'sourceRef': '@1:1',
        'targetRef': '@1:2',
      }),
      const BrowsewellCommand('upload', <String, Object?>{
        'ref': '@1:1',
        'filePaths': <String>['/tmp/file'],
      }),
      const BrowsewellCommand('scroll', <String, Object?>{
        'deltaX': 0.0,
        'deltaY': 100.0,
      }),
    ]) {
      await platform.execute(id, command);
    }
    expect(
      await platform.execute(
        id,
        const BrowsewellCommand('evaluate', <String, Object?>{
          'function': '() => document.title',
        }),
      ),
      'Fixture',
    );
    expect(
      nativeCalls.map((call) => call.method),
      containsAll(<String>{
        'click',
        'hover',
        'type',
        'keypress',
        'select',
        'drag',
        'upload',
        'scroll',
        'screenshot',
      }),
    );

    await platform.disposeBrowser(id);
    expect(
      () => platform.events(id),
      throwsA(isA<BrowsewellException>()),
    );
  });

  test('rejects unknown commands and times out unmet waits', () async {
    final created = await platform.create(
      BrowsewellCreateRequest(
        profile: const BrowsewellProfile(directory: '/profile'),
        initialUrl: Uri.parse('about:blank'),
        policy: const BrowsewellPolicy(),
      ),
    );
    webviews.controller.waitMatches = false;
    await expectLater(
      platform.execute(created.id, const BrowsewellCommand('unknown')),
      throwsA(isA<BrowsewellException>()),
    );
    await expectLater(
      platform.execute(
        created.id,
        const BrowsewellCommand('wait', <String, Object?>{
          'url': 'never',
          'timeoutMs': 1,
        }),
      ),
      throwsA(isA<BrowsewellException>()),
    );
  });

  test('rejects stale refs and policy-sized results', () async {
    final created = await platform.create(
      BrowsewellCreateRequest(
        profile: const BrowsewellProfile(directory: '/profile'),
        initialUrl: Uri.parse('about:blank'),
        policy: const BrowsewellPolicy(
          maxEvaluateResultBytes: 4,
          maxScreenshotBytes: 3,
        ),
      ),
    );
    final first =
        (await platform.execute(
              created.id,
              const BrowsewellCommand('snapshot'),
            ))!
            as Map<Object?, Object?>;
    await platform.execute(created.id, const BrowsewellCommand('snapshot'));

    await expectLater(
      platform.execute(
        created.id,
        BrowsewellCommand('click', <String, Object?>{
          'ref': '@${first['generation']}:1',
        }),
      ),
      throwsA(
        isA<BrowsewellException>().having(
          (error) => error.code,
          'code',
          BrowsewellErrorCode.staleRef,
        ),
      ),
    );
    await expectLater(
      platform.execute(
        created.id,
        const BrowsewellCommand('evaluate', <String, Object?>{
          'function': '() => "oversized"',
        }),
      ),
      throwsA(
        isA<BrowsewellException>().having(
          (error) => error.code,
          'code',
          BrowsewellErrorCode.denied,
        ),
      ),
    );
    await expectLater(
      platform.execute(
        created.id,
        const BrowsewellCommand('screenshot', <String, Object?>{
          'fullPage': false,
        }),
      ),
      throwsA(
        isA<BrowsewellException>().having(
          (error) => error.code,
          'code',
          BrowsewellErrorCode.denied,
        ),
      ),
    );
  });

  testWidgets('captures the Windows texture for viewport and full page', (
    tester,
  ) async {
    platform = WebviewAllBrowsewellPlatform(captureFlutterTexture: true);
    final created = await platform.create(
      BrowsewellCreateRequest(
        profile: const BrowsewellProfile(directory: '/profile'),
        initialUrl: Uri.parse('about:blank'),
        policy: const BrowsewellPolicy(),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 20,
          height: 20,
          child: platform.buildView(created.id),
        ),
      ),
    );
    await tester.pump();
    for (final fullPage in <bool>[false, true]) {
      final png =
          (await tester.runAsync(
                () => platform.execute(
                  created.id,
                  BrowsewellCommand('screenshot', <String, Object?>{
                    'fullPage': fullPage,
                  }),
                ),
              ))!
              as Uint8List;
      expect(png.take(4), orderedEquals(<int>[137, 80, 78, 71]));
    }
  });
}

final class _FakeWebViewPlatform extends WebViewPlatform
    with MockPlatformInterfaceMixin {
  final controller = _FakeController();
  final delegate = _FakeNavigationDelegate();

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller;

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate;

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWidget(params);
}

final class _FakeController extends PlatformWebViewController {
  _FakeController()
    : super.implementation(const PlatformWebViewControllerCreationParams());

  void Function(JavaScriptConsoleMessage message)? console;
  Future<void> Function(JavaScriptAlertDialogRequest request)? alert;
  Future<bool> Function(JavaScriptConfirmDialogRequest request)? confirm;
  Future<String> Function(JavaScriptTextInputDialogRequest request)? prompt;
  bool waitMatches = true;
  int snapshotGeneration = 0;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage message) onConsoleMessage,
  ) async => console = onConsoleMessage;

  @override
  Future<void> setOnJavaScriptAlertDialog(
    Future<void> Function(JavaScriptAlertDialogRequest request) callback,
  ) async => alert = callback;

  @override
  Future<void> setOnJavaScriptConfirmDialog(
    Future<bool> Function(JavaScriptConfirmDialogRequest request) callback,
  ) async => confirm = callback;

  @override
  Future<void> setOnJavaScriptTextInputDialog(
    Future<String> Function(JavaScriptTextInputDialogRequest request) callback,
  ) async => prompt = callback;

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> goBack() async {}

  @override
  Future<void> goForward() async {}

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getTitle() async => 'Fixture';

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    if (javaScript.contains('__browsewellGeneration')) {
      snapshotGeneration += 1;
      return '{"generation":$snapshotGeneration,'
          '"document":{"role":"document","name":"Fixture"}}';
    }
    if (javaScript.contains('getBoundingClientRect')) {
      return <String, Object?>{
        'left': 1.0,
        'top': 2.0,
        'width': 10.0,
        'height': 12.0,
      };
    }
    if (javaScript.contains("getEntriesByType('resource')")) {
      return <Object?>[
        <String, Object?>{
          'name': 'https://example.test/resource',
          'duration': 2.0,
        },
      ];
    }
    if (javaScript.contains('document.documentElement.scrollHeight')) {
      return <String, Object?>{'height': 30, 'x': 0.0, 'y': 0.0};
    }
    if (javaScript.contains('scrollY')) return 0.0;
    if (javaScript.contains('includes(')) return waitMatches;
    if (javaScript.contains('document.title')) return '"Fixture"';
    if (javaScript.contains('oversized')) return '"oversized"';
    return true;
  }
}

final class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate()
    : super.implementation(const PlatformNavigationDelegateCreationParams());

  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async =>
      onPageStarted = callback;

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      onPageFinished = callback;

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}

final class _FakeWidget extends PlatformWebViewWidget {
  _FakeWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
