/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    10| * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/models/novel_recom_response.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';

part 'novel_lighting_store.g.dart';

class NovelLightingStore = _NovelLightingStoreBase with _$NovelLightingStore;

abstract class _NovelLightingStoreBase with Store {
  FutureGet source;
  LightSource? lightSource;
  final ApiClient _client = apiClient;
  final EasyRefreshController controller;

  /// Shorter than the client timeout so a request that never reaches the
  /// network (a stalled interceptor queue) still surfaces instead of leaving
  /// the refresh indicator spinning forever.
  Duration timeout = const Duration(seconds: 30);

  _NovelLightingStoreBase(this.source, this.controller, {this.lightSource}) {
    if (lightSource is ApiPagedSource) {
      currentPage = (lightSource as ApiPagedSource).initialPage;
    }
  }

  String? nextUrl;
  ObservableList<NovelStore> novels = ObservableList();
  @observable
  String? errorMessage;
  @observable
  bool refreshing = false;
  @observable
  int currentPage = 1;

  int _sourceRevision = 0;
  bool _lock = false;

  Future<Response> _timed(Future<Response> request) {
    return request.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Pixiv did not answer in ${timeout.inSeconds}s',
      ),
    );
  }

  Future<Response> _fetchResponse({bool force = false, int? page}) {
    final requestSource = lightSource;
    if (requestSource is ApiPagedSource) {
      return _timed(requestSource.fetch(page ?? requestSource.initialPage, force));
    }
    if (requestSource is ApiForceSource) {
      return _timed(requestSource.fetch(force));
    }
    if (requestSource is ApiSource) {
      return _timed(requestSource.fetch());
    }
    return _timed(source());
  }

  void _replaceNovels(List<Novel> novels) {
    this.novels
      ..clear()
      ..addAll(novels.map((element) => NovelStore(element.id, element)));
  }

  @action
  Future<void> fetch() async {
    if (_lock) return;
    _lock = true;
    final requestRevision = _sourceRevision;
    nextUrl = null;
    errorMessage = null;
    refreshing = true;
    try {
      final requestSource = lightSource;
      final fetchedPage =
          requestSource is ApiPagedSource ? requestSource.initialPage : null;
      final response = await _fetchResponse(force: true, page: fetchedPage);
      if (requestRevision != _sourceRevision) return;
      final novelRecomResponse = NovelRecomResponse.fromJson(response.data);
      if (fetchedPage != null &&
          fetchedPage > 1 &&
          novelRecomResponse.novels.isEmpty) {
        errorMessage = 'Page $fetchedPage has no results';
        controller.finishRefresh(IndicatorResult.noMore);
        return;
      }
      nextUrl = novelRecomResponse.nextUrl;
      _replaceNovels(novelRecomResponse.novels);
      if (fetchedPage != null) currentPage = fetchedPage;
      controller.finishRefresh(IndicatorResult.success);
    } catch (e) {
      print(e);
      errorMessage = e.toString();
      controller.finishRefresh(IndicatorResult.fail);
    } finally {
      refreshing = false;
      _lock = false;
      if (_sourceRevision != requestRevision) {
        scheduleMicrotask(fetch);
      }
    }
  }

  /// Reloads a numbered page. Failed or empty pages keep the current list.
  @action
  Future<bool> fetchPage(int page, {bool force = false}) async {
    if (_lock || lightSource is! ApiPagedSource || page < 1) return false;
    _lock = true;
    final requestRevision = _sourceRevision;
    refreshing = true;
    try {
      final response = await _fetchResponse(force: force, page: page);
      if (requestRevision != _sourceRevision) return false;
      final novelRecomResponse = NovelRecomResponse.fromJson(response.data);
      if (novelRecomResponse.novels.isEmpty) {
        controller.finishRefresh(IndicatorResult.noMore);
        return false;
      }
      nextUrl = novelRecomResponse.nextUrl;
      _replaceNovels(novelRecomResponse.novels);
      currentPage = page;
      errorMessage = null;
      controller.finishRefresh(IndicatorResult.success);
      return true;
    } catch (_) {
      controller.finishRefresh(IndicatorResult.fail);
      return false;
    } finally {
      refreshing = false;
      _lock = false;
      if (_sourceRevision != requestRevision) {
        scheduleMicrotask(fetch);
      }
    }
  }

  @action
  Future<void> update(LightSource next, {bool force = false}) async {
    lightSource = next;
    _sourceRevision++;
    if (next is ApiPagedSource) {
      currentPage = next.initialPage;
    }
    if (_lock) return;
    await fetch();
  }

  @action
  Future<void> next() async {
    if (lightSource is ApiPagedSource) {
      controller.finishLoad(IndicatorResult.noMore);
      return;
    }
    if (nextUrl != null && nextUrl!.isNotEmpty) {
      try {
        Response response = await _timed(_client.getNext(nextUrl!));
        NovelRecomResponse novelRecomResponse =
            NovelRecomResponse.fromJson(response.data);
        nextUrl = novelRecomResponse.nextUrl;
        final novel = novelRecomResponse.novels;
        novels.addAll(novel.map((element) => NovelStore(element.id, element)));
        controller.finishLoad(IndicatorResult.success);
      } catch (e) {
        controller.finishLoad(IndicatorResult.fail);
      }
    } else {
      controller.finishLoad(IndicatorResult.noMore);
    }
  }
}
