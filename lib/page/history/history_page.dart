/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/material.dart' show Card, EdgeInsets;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/models/illust_persist.dart';
import 'package:pixez/page/history/illust_history_origin.dart';
import 'package:pixez/page/history/history_store.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/utils/haptic_util.dart';
import 'package:pixez/page/search/result_page.dart';

enum _HistoryAction { delete, openSourceSearch }

class HistoryPage extends HookConsumerWidget {
  const HistoryPage({super.key});

  Widget buildAppBarUI(context) => Container(
        child: Padding(
          child: Text(
            I18n.of(context).history,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30.0),
          ),
          padding: EdgeInsets.only(left: 20.0, top: 30.0, bottom: 30.0),
        ),
      );

  Widget buildBody(List<IllustPersist> data, WidgetRef ref) {
    final reIllust = data.reversed.toList();
    if (reIllust.isNotEmpty) {
      return LayoutBuilder(builder: (context, snapshot) {
        final rowCount = max(2, (snapshot.maxWidth / 200).floor());
        return GridView.builder(
            itemCount: reIllust.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: rowCount),
            itemBuilder: (context, index) {
              final history = reIllust[index];
              return GestureDetector(
                  onTap: () {
                    HapticUtil.selectionClick();
                    Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (BuildContext context) {
                      return IllustLightingPage(
                          id: history.illustId,
                          store: IllustStore(history.illustId, null)
                            ..setSearchOrigin(
                              queryJson: history.sourceQueryJson,
                              page: history.sourcePage,
                            ));
                    }));
                  },
                  onLongPress: () {
                    HapticUtil.heavy();
                    _showHistoryActions(context, ref, history);
                  },
                  onSecondaryTap: () =>
                      _showHistoryActions(context, ref, history),
                  child: Card(
                      margin: EdgeInsets.all(8),
                      child: PixivImage(history.pictureUrl)));
            });
      });
    }
    return Center(
      child: Container(),
    );
  }

  Future<void> _showHistoryActions(
    BuildContext context,
    WidgetRef ref,
    IllustPersist history,
  ) async {
    final sourceQuery = restoreIllustHistoryOrigin(history);
    final action = await showDialog<_HistoryAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(I18n.of(context).history_item_actions),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(I18n.of(context).cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_HistoryAction.delete),
            child: Text(I18n.of(context).delete),
          ),
          if (sourceQuery != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_HistoryAction.openSourceSearch),
              child: Text(
                I18n.of(context).jump_to_source_search_page(
                  sourceQuery.normalizedPage,
                ),
              ),
            ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _HistoryAction.delete:
        await ref.read(historyProvider.notifier).delete(history.illustId);
        return;
      case _HistoryAction.openSourceSearch:
        if (sourceQuery == null) return;
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => ResultPage(
              word: sourceQuery.word,
              translatedName: sourceQuery.translatedName,
              initialQuery: sourceQuery,
            ),
          ),
        );
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataFuture = ref.watch(historyProvider);
    final _textEditingController = useTextEditingController();
    useEffect(() {
      Future.delayed(Duration.zero, () async {
        await ref.read(historyProvider.notifier).fetch();
      });
      return null;
    }, []);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
            controller: _textEditingController,
            onChanged: (word) {
              if (word.trim().isNotEmpty) {
                ref.read(historyProvider.notifier).search(word.trim());
              } else {
                ref.read(historyProvider.notifier).fetch();
              }
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: I18n.of(context).search_word_hint,
            )),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              _textEditingController.clear();
              ref.read(historyProvider.notifier).fetch();
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.delete),
        onPressed: () {
          _cleanAll(context, ref);
        },
      ),
      body: buildBody(dataFuture.data, ref),
    );
  }

  Future<void> _cleanAll(BuildContext context, WidgetRef ref) async {
    final result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("${I18n.of(context).delete} ${I18n.of(context).all}?"),
            actions: <Widget>[
              TextButton(
                child: Text(I18n.of(context).cancel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text(I18n.of(context).ok),
                onPressed: () {
                  Navigator.of(context).pop("OK");
                },
              ),
            ],
          );
        });
    if (result == "OK") {
      ref.read(historyProvider.notifier).deleteAll();
    }
  }
}
