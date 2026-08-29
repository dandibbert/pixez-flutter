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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:dio/dio.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/novel_recom_response.dart';
import 'package:pixez/models/novel_viewer_persist.dart';
import 'package:pixez/models/novel_web_response.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/novel/viewer/image_text.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

part 'novel_store.g.dart';

class NovelStore = _NovelStoreBase with _$NovelStore;

abstract class _NovelStoreBase with Store {
  final int id;

  _NovelStoreBase(this.id, this.novel);

  @observable
  Novel? novel;
  @observable
  NovelWebResponse? novelTextResponse;
  @observable
  String? errorMessage;
  @observable
  bool positionBooked = false;

  @observable
  double bookedOffset = 0.0;
  @observable
  List<NovelSpansData> spans = [];

  NovelViewerPersistProvider _novelViewerPersistProvider =
      NovelViewerPersistProvider();

  @action
  bookPosition(double offset) async {
    LPrinter.d("bookPosition $offset");
    await _novelViewerPersistProvider.open();
    await _novelViewerPersistProvider.insert(
      NovelViewerPersist(novelId: id, offset: offset),
    );
    positionBooked = true;
  }

  @action
  deleteBookPosition() async {
    LPrinter.d("deleteBookPosition");
    await _novelViewerPersistProvider.open();
    await _novelViewerPersistProvider.delete(id);
    positionBooked = false;
  }

  @action
  Future<void> fetch() async {
    errorMessage = null;
    try {
      bookedOffset = 0.0;
      final response = await apiClient.webviewNovel(id);
      // Building the DOM for a pixiv page and decoding its payload costs tens
      // of milliseconds; run it in the same isolate hop as span building so a
      // chapter never stalls the UI thread.
      final document = await compute(
        parseNovelDocument,
        response.data as String,
      );
      novelTextResponse = document.webResponse;
      spans = document.spans;
      if (novel == null) {
        Response response = await apiClient.getNovelDetail(id);
        novel = Novel.fromJson(response.data['novel']);
      }
      novelHistoryStore.insert(novel!);
      fetchOffset();
    } catch (e) {
      print(e);
      errorMessage = e.toString();
    }
  }

  @action
  fetchOffset() async {
    try {
      await _novelViewerPersistProvider.open();
      final result = await _novelViewerPersistProvider.getNovelPersistById(id);
      if (result != null) {
        LPrinter.d("fetchOffset ${result.offset}");
        positionBooked = true;
        bookedOffset = result.offset;
      }
    } catch (e) {}
  }
}

class NovelDocument {
  final NovelWebResponse webResponse;
  final List<NovelSpansData> spans;

  const NovelDocument(this.webResponse, this.spans);
}

/// Turns a pixiv novel page into the model and the spans the reader renders.
/// Meant to run off the UI isolate via [compute].
NovelDocument parseNovelDocument(String html) {
  final json = parseNovelJsonFromHtml(html);
  if (json == null) {
    throw FormatException('Unable to parse novel data from Pixiv HTML');
  }
  final webResponse = NovelWebResponse.fromJson(jsonDecode(json));
  return NovelDocument(
    webResponse,
    NovelSpansGenerator().buildSpans(webResponse),
  );
}

String? parseNovelJsonFromHtml(String html) {
  final document = parse(html);
  for (final scriptElement in document.querySelectorAll('script')) {
    final scriptContent = scriptElement.innerHtml;
    final novelIndex = scriptContent.indexOf('novel:');
    if (novelIndex == -1) {
      continue;
    }
    final objectStart = scriptContent.indexOf('{', novelIndex);
    if (objectStart == -1) {
      continue;
    }
    return _readBalancedJsonObject(scriptContent, objectStart);
  }
  return null;
}

String? _readBalancedJsonObject(String source, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;

  for (var i = start; i < source.length; i++) {
    final char = source[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }

    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }
  return null;
}
