import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/er/deep_link_router.dart';

class _Home extends StatefulWidget {
  const _Home(this.name, {this.initialLink});

  final String name;
  final Future<Uri?> Function()? initialLink;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  void initState() {
    super.initState();
    DeepLinkRouter.attach(this, initialLink: widget.initialLink);
  }

  @override
  void dispose() {
    DeepLinkRouter.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.name);
}

void main() {
  late StreamController<Uri?> links;
  late List<String> opened;

  setUp(() async {
    await DeepLinkRouter.reset();
    links = StreamController<Uri?>.broadcast();
    opened = [];
    DeepLinkRouter.linkSource = () => links.stream;
    DeepLinkRouter.open = (context, link) {
      opened.add('${(context.widget as _Home).name}:$link');
    };
  });

  tearDown(() => links.close());

  testWidgets('links keep opening after switching to the novel home', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var launchReads = 0;
    Future<Uri?> launch() async {
      launchReads++;
      return Uri.parse('pixez://www.pixiv.net/artworks/1');
    }

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: _Home('illust', initialLink: launch),
      ),
    );
    await tester.pump();
    expect(opened, ['illust:pixez://www.pixiv.net/artworks/1']);

    // The novel section replaces the illust home.
    navigator.currentState!.pushReplacement(
      MaterialPageRoute(builder: (_) => const _Home('novel')),
    );
    await tester.pumpAndSettle();
    links.add(Uri.parse('https://www.pixiv.net/artworks/2'));
    await tester.pump();
    await tester.pump();
    expect(opened.last, 'novel:https://www.pixiv.net/artworks/2');

    // Switching back does not replay the launch link.
    navigator.currentState!.pushReplacement(
      MaterialPageRoute(builder: (_) => _Home('illust', initialLink: launch)),
    );
    await tester.pumpAndSettle();
    expect(launchReads, 1);
    expect(opened, hasLength(2));
    links.add(Uri.parse('https://www.pixiv.net/novel/show.php?id=3'));
    await tester.pump();
    await tester.pump();
    expect(opened.last, 'illust:https://www.pixiv.net/novel/show.php?id=3');
  });

  testWidgets('a link that arrives with no home waits for the next one', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _Home('illust')));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    links.add(Uri.parse('https://www.pixiv.net/artworks/4'));
    await tester.pump();
    await tester.pump();
    expect(opened, isEmpty);
    await tester.pumpWidget(const MaterialApp(home: _Home('novel')));
    await tester.pump();
    expect(opened, ['novel:https://www.pixiv.net/artworks/4']);
  });
}
