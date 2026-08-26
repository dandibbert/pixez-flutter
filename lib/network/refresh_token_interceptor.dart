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
import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';
import 'package:pixez/models/error_message.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/network/oauth_client.dart';

class RefreshTokenInterceptor extends QueuedInterceptorsWrapper {
  RefreshTokenInterceptor({Future<String?> Function()? tokenReader})
      : _tokenReader = tokenReader;

  final Future<String?> Function()? _tokenReader;

  Future<String?> getToken() async {
    final reader = _tokenReader;
    if (reader != null) return reader();
    String? token = accountStore.now?.accessToken; //可能读的时候没有错的快，导致now为null
    String result;
    if (token != null)
      result = "Bearer " + token;
    else {
      AccountProvider accountProvider = AccountProvider();
      await accountProvider.open();
      final all = await accountProvider.getAllAccount();
      if (all.isEmpty) return null;
      final index = accountStore.index;
      final account = index >= 0 && index < all.length ? all[index] : all.first;
      result = "Bearer " + account.accessToken;
    }
    return result;
  }

  /// A queued interceptor only advances its queue when the handler is called.
  /// If a callback throws asynchronously the handler is never called, so that
  /// request and every request behind it hang forever with no error. Every
  /// path below must end in next/resolve/reject.
  static const Duration _retryTimeout = Duration(seconds: 20);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      if (!options.path.contains('v1/walkthrough/illusts')) {
        options.headers[OAuthClient.AUTHORIZATION] = await getToken();
        if (options.headers[OAuthClient.AUTHORIZATION] == null) {
          return handler.reject(DioException(requestOptions: options));
        }
      }
    } catch (e, stackTrace) {
      return handler.reject(DioException(
        requestOptions: options,
        error: e,
        stackTrace: stackTrace,
        message: 'Could not read the access token: $e',
      ));
    }
    return handler.next(options);
  }

  int bti(bool bool) {
    if (bool) {
      return 1;
    } else
      return 0;
  }

  int lastRefreshTime = 0;
  int retryNum = 0;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    retryNum = -2;
    return handler.next(response);
  }

  bool isRefreshing = false;

  @override
  void onError(DioException err, handler) async {
    if (err.response != null && err.response!.statusCode == 400) {
      DateTime dateTime = DateTime.now();
      if ((dateTime.millisecondsSinceEpoch - lastRefreshTime) > 200000) {
        try {
          print("lock start ========================");
          ErrorMessage errorMessage = ErrorMessage.fromJson(err.response!.data);
          if (errorMessage.error.message!.contains("OAuth") &&
              accountStore.now != null) {
            final client = OAuthClient();
            await client.createDioClient();
            AccountPersist accountPersist = accountStore.now!;
            Response response1 = await client.postRefreshAuthToken(
                refreshToken: accountPersist.refreshToken,
                deviceToken: accountPersist.deviceToken);
            AccountResponse accountResponse =
                Account.fromJson(response1.data).response;
            final user = accountResponse.user;
            await accountStore.updateSingle(AccountPersist(
                userId: user.id,
                userImage: user.profileImageUrls.px170x170,
                accessToken: accountResponse.accessToken,
                refreshToken: accountResponse.refreshToken,
                deviceToken: "",
                passWord: "no more",
                name: user.name,
                account: user.account,
                mailAddress: user.mailAddress,
                isPremium: bti(user.isPremium),
                xRestrict: user.xRestrict,
                isMailAuthorized: bti(user.isMailAuthorized),
                id: accountPersist.id));
            lastRefreshTime = DateTime.now().millisecondsSinceEpoch;
            print("unlock ========================");
          } else if (errorMessage.error.message!.contains("Limit")) {
            lastRefreshTime = 0;
            print("unlock ========================");
            return handler.reject(err);
          } else {
            lastRefreshTime = 0;
            print("unlock ========================");
            return handler.reject(err);
          }
        } catch (e) {
          print(e);
          lastRefreshTime = 0;
          print("unlock ========================");
          return handler.reject(err);
        }
      }
      var option = err.requestOptions;
      try {
        final newToken = (await getToken());
        print("unlock retry ======================== $newToken");
        option.headers[OAuthClient.AUTHORIZATION] = newToken;
        var response = await apiClient.httpClient
            .request(
              option.path,
              data: option.data,
              queryParameters: option.queryParameters,
              cancelToken: option.cancelToken,
              options: Options(
                method: option.method,
                headers: option.headers,
                contentType: option.contentType,
              ),
            )
            .timeout(_retryTimeout);
        return handler.resolve(response);
      } catch (e) {
        print(e);
        return handler.reject(err);
      }
    }
    if (err.message?.contains(
                "Connection closed before full header was received") ==
            true &&
        retryNum < 2) {
      print('retry $retryNum =========================');
      retryNum++;
      RequestOptions options = err.requestOptions;
      try {
        var response = await apiClient.httpClient
            .request(
              options.path,
              options: Options(
                method: options.method,
                headers: options.headers,
                contentType: options.contentType,
              ),
              data: options.data,
              queryParameters: options.queryParameters,
            )
            .timeout(_retryTimeout);
        return handler.resolve(response);
      } catch (e) {
        print(e);
        return handler.reject(err);
      }
    }
    return handler.reject(err);
  }
}
