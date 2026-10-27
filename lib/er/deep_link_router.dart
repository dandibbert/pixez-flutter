import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pixez/deep_link_plugin.dart';
import 'package:pixez/er/leader.dart';

/// Opens incoming links for the whole app, whichever home is showing.
///
/// The illust home and the novel section replace each other, so a listener
/// owned by either one went away on every switch: links that arrived while
/// novels were open were dropped, and switching back read the cold-start link
/// again. Homes now [attach] while they are on screen; the subscription and
/// the cold-start link live here, once for the app.
class DeepLinkRouter {
  DeepLinkRouter._();

  @visibleForTesting
  static Stream<Uri?> Function() linkSource = () =>
      DeepLinkPlugin.uriLinkStream;

  @visibleForTesting
  static void Function(BuildContext context, Uri link) open = (context, link) =>
      Leader.pushWithUri(context, link);

  static final List<State> _hosts = [];
  static final List<Uri> _pending = [];
  static StreamSubscription<Uri?>? _sub;
  static bool _initialLinkRead = false;

  /// Starts routing links into [host]. The first home to attach also reads
  /// the link the app was launched with, through [initialLink].
  static void attach(State host, {Future<Uri?> Function()? initialLink}) {
    _hosts
      ..remove(host)
      ..add(host);
    _sub ??= linkSource().listen((link) {
      if (link != null) _enqueue(link);
    }, onError: (Object error) => debugPrint('Deep link stream: $error'));
    if (!_initialLinkRead) {
      _initialLinkRead = true;
      _readInitialLink(initialLink ?? DeepLinkPlugin.getInitialUri);
    }
    _flush();
  }

  static void detach(State host) => _hosts.remove(host);

  static Future<void> _readInitialLink(Future<Uri?> Function() read) async {
    try {
      final link = await read();
      if (link != null) _enqueue(link);
    } catch (error) {
      debugPrint('Initial deep link: $error');
    }
  }

  static void _enqueue(Uri link) {
    _pending.add(link);
    _flush();
  }

  /// Opens pending links after the next frame, when the Navigator is ready.
  /// Links that arrive while no home is on screen wait for the next one.
  static void _flush() {
    if (_pending.isEmpty) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        State? host;
        for (final candidate in _hosts.reversed) {
          if (candidate.mounted) {
            host = candidate;
            break;
          }
        }
        if (host == null || _pending.isEmpty) return;
        final links = List.of(_pending);
        _pending.clear();
        for (final link in links) {
          open(host.context, link);
        }
      })
      ..scheduleFrame();
  }

  @visibleForTesting
  static Future<void> reset() async {
    await _sub?.cancel();
    _sub = null;
    _hosts.clear();
    _pending.clear();
    _initialLinkRead = false;
  }
}
