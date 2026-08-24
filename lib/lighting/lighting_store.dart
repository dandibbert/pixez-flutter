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

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/glance_illust_persist.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/models/recommend.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/picture/illust_store.dart';

part 'lighting_store.g.dart';

class LightingStore = _LightingStoreBase with _$LightingStore;

typedef Future<Response> FutureGet();
typedef Future<Response> FutureRefreshGet(bool force);
typedef Future<Response> FuturePageGet(int page, bool force);

abstract class LightSource {
  String? glanceKey;

  LightSource({this.searchQueryJson, this.searchPage});

  final String? searchQueryJson;
  final int? searchPage;
}

class ApiSource extends LightSource {
  FutureGet futureGet;

  String? g;

  ApiSource({
    required this.futureGet,
    String? searchQueryJson,
    int? searchPage,
  }) : super(searchQueryJson: searchQueryJson, searchPage: searchPage);

  Future<Response> fetch() {
    return futureGet();
  }
}

class ApiForceSource extends LightSource {
  FutureRefreshGet futureGet;

  ApiForceSource({
    required this.futureGet,
    String? glanceKey = null,
    String? searchQueryJson,
    int? searchPage,
  }) : super(searchQueryJson: searchQueryJson, searchPage: searchPage) {
    this.glanceKey = glanceKey;
  }

  Future<Response> fetch(bool force) {
    return futureGet(force);
  }
}

class ApiPagedSource extends LightSource {
  ApiPagedSource({
    required this.futureGet,
    this.initialPage = 1,
    String? searchQueryJson,
    int? searchPage,
  }) : super(searchQueryJson: searchQueryJson, searchPage: searchPage);

  final FuturePageGet futureGet;
  final int initialPage;

  Future<Response> fetch(int page, bool force) {
    return futureGet(page < 1 ? 1 : page, force);
  }
}

abstract class _LightingStoreBase with Store {
  late LightSource source;
  String? nextUrl;
  EasyRefreshController? easyRefreshController;
  Function? onChange;
  String? portal;
  @observable
  ObservableList<IllustStore> iStores = ObservableList();
  @observable
  bool refreshing = false;
  @observable
  int currentPage = 1;

  int _sourceRevision = 0;
  Completer<bool>? _pendingSourceCompleter;
  bool _pendingSourceForce = false;
  int? _lastSearchPage;

  GlanceIllustPersistProvider glanceIllustPersistProvider =
      GlanceIllustPersistProvider();

  dispose() {
    // iStores.forEach((element) {
    //   final provider = ExtendedNetworkImageProvider(
    //     element.illusts.imageUrls.medium,
    //   );
    //   provider.evict();
    // });
    // iStores.clear();
  }

  @observable
  String? errorMessage;

  _LightingStoreBase(this.source) {
    _lastSearchPage = source.searchPage;
    if (source is ApiPagedSource) {
      currentPage = (source as ApiPagedSource).initialPage;
    }
  }

  void _releaseLockAndRunPending() {
    refreshing = false;
    _lock = false;
    final completer = _pendingSourceCompleter;
    if (completer == null) return;
    final force = _pendingSourceForce;
    _pendingSourceCompleter = null;
    _pendingSourceForce = false;
    unawaited(
      Future<void>(() async {
        try {
          completer.complete(await fetch(force: force));
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      }),
    );
  }

  bool okForUser(Illusts illust) {
    // if (userSetting.hIsNotAllow)
    //   for (int i = 0; i < illust.tags.length; i++)
    //     if (illust.tags[i].name.startsWith('R-18')) return false;
    for (var t in muteStore.banTags) {
      for (var f in illust.tags) {
        if (f.name == t.name) return false;
      }
    }
    for (var j in muteStore.banUserIds) {
      if (j.userId == illust.user.id.toString()) {
        return false;
      }
    }
    for (var i in muteStore.banillusts)
      if (illust.id == i.id) {
        return false;
      }
    return true;
  }

  bool _lock = false;

  @action
  Future<bool> fetch({String? url, bool force = false}) async {
    if (_lock) return false;
    _lock = true;
    final requestRevision = _sourceRevision;
    final requestSource = source;
    nextUrl = null;
    errorMessage = null;
    refreshing = true;
    try {
      Response? result = null;
      int? fetchedPage;
      if (requestSource is ApiSource) {
        result = await requestSource.fetch();
      } else if (requestSource is ApiForceSource) {
        result = await requestSource.fetch(force);
      } else if (requestSource is ApiPagedSource) {
        fetchedPage = requestSource.initialPage;
        result = await requestSource.fetch(fetchedPage, force);
      }

      if (requestRevision != _sourceRevision) return false;
      Recommend recommend = Recommend.fromJson(result!.data);
      if (fetchedPage != null && fetchedPage > 1 && recommend.illusts.isEmpty) {
        errorMessage = 'Page $fetchedPage has no results';
        easyRefreshController?.finishRefresh(IndicatorResult.noMore);
        return false;
      }
      //https://app-api.pixiv.net/v1/user/illusts?filter=for_android&user_id=${user_id}&type=illust&offset=30
      nextUrl = recommend.nextUrl;
      iStores.clear();
      final sourcePage = fetchedPage ?? requestSource.searchPage;
      iStores.addAll(
        recommend.illusts.map(
          (illust) => IllustStore(illust.id, illust)
            ..setSearchOrigin(
              queryJson: requestSource.searchQueryJson,
              page: sourcePage,
            ),
        ),
      );
      _lastSearchPage = sourcePage;
      if (fetchedPage != null) currentPage = fetchedPage;
      String? glanceKey = requestSource.glanceKey;
      if (glanceKey != null && glanceKey.isNotEmpty) {
        await glanceIllustPersistProvider.open();
        await glanceIllustPersistProvider.insertAll(
          recommend.illusts
              .where((element) => !element.hateByUser(includeR18Setting: true))
              .toGlancePersist(
                glanceKey,
                DateTime.now().microsecondsSinceEpoch,
              ),
        );
      }
      easyRefreshController?.finishRefresh(IndicatorResult.success);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      easyRefreshController?.finishRefresh(IndicatorResult.fail);
      return false;
    } finally {
      _releaseLockAndRunPending();
    }
  }

  /// 按页重新请求并替换当前结果。失败或空页不会改变现有页码和作品列表。
  @action
  Future<bool> fetchPage(int page, {bool force = false}) async {
    if (_lock || source is! ApiPagedSource || page < 1) return false;
    _lock = true;
    final requestRevision = _sourceRevision;
    final requestSource = source as ApiPagedSource;
    refreshing = true;
    try {
      final result = await requestSource.fetch(page, force);
      if (requestRevision != _sourceRevision) return false;
      final recommend = Recommend.fromJson(result.data);
      if (recommend.illusts.isEmpty) {
        easyRefreshController?.finishRefresh(IndicatorResult.noMore);
        return false;
      }
      nextUrl = recommend.nextUrl;
      final stores = recommend.illusts
          .map(
            (illust) => IllustStore(illust.id, illust)
              ..setSearchOrigin(
                queryJson: requestSource.searchQueryJson,
                page: page,
              ),
          )
          .toList(growable: false);
      iStores
        ..clear()
        ..addAll(stores);
      currentPage = page;
      _lastSearchPage = page;
      errorMessage = null;
      easyRefreshController?.finishRefresh(IndicatorResult.success);
      return true;
    } catch (_) {
      easyRefreshController?.finishRefresh(IndicatorResult.fail);
      return false;
    } finally {
      _releaseLockAndRunPending();
    }
  }

  @action
  Future<bool> update(LightSource futureGet, {bool force = false}) {
    source = futureGet;
    _lastSearchPage = futureGet.searchPage;
    _sourceRevision++;
    if (!_lock) return fetch(force: force);

    _pendingSourceCompleter?.complete(false);
    final completer = Completer<bool>();
    _pendingSourceCompleter = completer;
    _pendingSourceForce = force;
    return completer.future;
  }

  @action
  Future<bool> fetchNext() async {
    if (_lock) return false;
    _lock = true;
    final requestRevision = _sourceRevision;
    final requestSource = source;
    errorMessage = null;
    try {
      if (nextUrl != null && nextUrl!.isNotEmpty) {
        Response result = await apiClient.getNext(nextUrl!);
        if (requestRevision != _sourceRevision) return false;
        Recommend recommend = Recommend.fromJson(result.data);
        nextUrl = recommend.nextUrl;
        final sourcePage = requestSource.searchQueryJson == null
            ? null
            : (_lastSearchPage ?? requestSource.searchPage ?? 1) + 1;
        var map = recommend.illusts.map(
          (illust) => IllustStore(illust.id, illust)
            ..setSearchOrigin(
              queryJson: requestSource.searchQueryJson,
              page: sourcePage,
            ),
        );
        if (portal == "new") {
          var iterable = iStores.map((element) => element.id);
          map = map.where((element) => !iterable.contains(element.id));
        }
        iStores.addAll(map);
        _lastSearchPage = sourcePage;
        easyRefreshController?.finishLoad(IndicatorResult.success);
      } else {
        easyRefreshController?.finishLoad(IndicatorResult.noMore);
      }
      return true;
    } catch (e) {
      easyRefreshController?.finishLoad(IndicatorResult.fail);
      return false;
    } finally {
      _releaseLockAndRunPending();
    }
  }
}
