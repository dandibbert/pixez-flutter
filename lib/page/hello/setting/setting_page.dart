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

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/new_version_chip.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/updater.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/account.dart';
import 'package:pixez/models/board_info.dart';
import 'package:pixez/models/glance_illust_persist.dart';
import 'package:pixez/page/about/about_page.dart';
import 'package:pixez/page/account/edit/account_edit_page.dart';
import 'package:pixez/page/account/select/account_select_page.dart';
import 'package:pixez/page/board/board_page.dart';
import 'package:pixez/page/book/tag/book_tag_page.dart';
import 'package:pixez/page/hello/recom/recom_manga_page.dart';
import 'package:pixez/page/hello/setting/data_export_page.dart';
import 'package:pixez/page/hello/setting/setting_quality_page.dart';
import 'package:pixez/page/history/history_page.dart';
import 'package:pixez/page/login/login_page.dart';
import 'package:pixez/page/novel/history/novel_history_page.dart';
import 'package:pixez/page/novel/novel_rail.dart';
import 'package:pixez/page/novel/tts/novel_tts_bar.dart';
import 'package:pixez/page/shield/shield_page.dart';
import 'package:pixez/page/task/job_page.dart';
import 'package:pixez/page/theme/theme_page.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';
import 'package:pixez/watercolor/watercolor_routes.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  @override
  void initState() {
    super.initState();
    initMethod();
    fetchBoard();
  }

  bool hideEmail = true;

  bool get _effectiveHasNewVersion =>
      Updater.result == Result.yes &&
      Updater.latestVersion != userSetting.ignoreUpdateVersion;

  initMethod() async {
    if (Constants.isGooglePlay || Platform.isIOS) return;
    if (Updater.result != Result.timeout) return;
    await Updater.check();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // In the watercolor style the rows scroll under the floating palette
        // bar and fade into the paper instead of stopping at its top edge.
        bottom: WatercolorTokens.of(context) == null,
        child: SingleChildScrollView(
          child: Padding(
            padding: WatercolorTokens.of(context) == null
                ? const EdgeInsets.all(8.0)
                : EdgeInsets.fromLTRB(
                    8,
                    8,
                    8,
                    8 + MediaQuery.paddingOf(context).bottom,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppBar(
                  elevation: 0.0,
                  automaticallyImplyLeading: false,
                  forceMaterialTransparency: true,
                  backgroundColor: Colors.transparent,
                  actions: [
                    IconButton(
                      icon: WcIcon(Icons.palette),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => ThemePage()),
                        );
                      },
                    ),
                  ],
                ),
                Observer(
                  builder: (context) {
                    if (accountStore.now != null)
                      return WcListGroup(
                        child: SingleChildScrollView(
                          child: Column(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).push(
                                      MaterialPageRoute(
                                        builder: (_) {
                                          return AccountSelectPage();
                                        },
                                      ),
                                    );
                                  },
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      PainterAvatar(
                                        url: accountStore.now!.userImage,
                                        id: int.parse(accountStore.now!.userId),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8.0,
                                                  ),
                                              child: Text(
                                                accountStore.now!.name,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                            ),
                                            if (accountStore
                                                .now!
                                                .mailAddress
                                                .isNotEmpty)
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    hideEmail
                                                        ? accountStore.now!
                                                              .hiddenEmail()
                                                        : accountStore
                                                              .now!
                                                              .mailAddress,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                  SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        hideEmail = !hideEmail;
                                                      });
                                                    },
                                                    child: Text(
                                                      hideEmail
                                                          ? I18n.of(
                                                              context,
                                                            ).reveal
                                                          : I18n.of(
                                                              context,
                                                            ).hide,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall!
                                                          .copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: WcListIcon(
                                  Icons.account_box,
                                  pigment: 0,
                                ),
                                title: Text(I18n.of(context).account_message),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (BuildContext context) =>
                                          AccountEditPage(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    return Container();
                  },
                ),
                if (WatercolorTokens.of(context) == null) Divider(),
                WcListGroup(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: WcListIcon(Icons.history, pigment: 1),
                        title: Text(I18n.of(context).history_record),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (BuildContext context) {
                                return Constants.type == 0
                                    ? HistoryPage()
                                    : NovelHistory();
                              },
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: WcListIcon(Icons.settings, pigment: 2),
                        title: Text(I18n.of(context).quality_setting),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (BuildContext context) {
                                return SettingQualityPage();
                              },
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: WcListIcon(Icons.bookmark, pigment: 3),
                        title: Text(I18n.of(context).favorited_tag),
                        onTap: () =>
                            Leader.pushWithScaffold(context, BookTagPage()),
                      ),
                      ListTile(
                        leading: WcListIcon(Icons.block, pigment: 4),
                        title: Text(I18n.of(context).shielding_settings),
                        onTap: () => Leader.push(context, ShieldPage()),
                      ),
                      ListTile(
                        leading: WcListIcon(Icons.save_alt, pigment: 0),
                        title: Text(I18n.of(context).task_progress),
                        onTap: () => Leader.push(context, JobPage()),
                      ),
                      ListTile(
                        onTap: () => Leader.push(context, DataExportPage()),
                        title: Text(I18n.of(context).app_data),
                        leading: WcListIcon(
                          Icons.folder_open_rounded,
                          pigment: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (WatercolorTokens.of(context) == null) Divider(),
                WcListGroup(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: WcListIcon(Icons.library_books, pigment: 2),
                        title: Text(I18n.of(context).manga),
                        onTap: () => Leader.push(context, RecomMangaPage()),
                      ),
                      // Inside the novel section this entry leads back to
                      // illusts instead of reopening novels.
                      if (Constants.type == 1)
                        ListTile(
                          leading: WcListIcon(Icons.image, pigment: 3),
                          title: Text(I18n.of(context).illust),
                          onTap: () => openIllustHome(context),
                        )
                      else
                        ListTile(
                          leading: WcListIcon(Icons.book, pigment: 3),
                          title: Text(I18n.of(context).novel),
                          onTap: () => openNovelRail(context),
                        ),
                      ListTile(
                        leading: WcListIcon(Icons.headphones, pigment: 4),
                        title: Text(I18n.of(context).novel_tts_settings),
                        subtitle: Text(
                          I18n.of(context).novel_tts_settings_subtitle,
                        ),
                        onTap: () => openNovelTtsSettings(context),
                      ),
                      ListTile(
                        leading: WcListIcon(Icons.message, pigment: 0),
                        title: Text(I18n.of(context).about),
                        onTap: () => Leader.push(
                          context,
                          AboutPage(newVersion: _effectiveHasNewVersion),
                        ),
                        trailing: Observer(
                          builder: (context) {
                            return Visibility(
                              child: NewVersionChip(),
                              visible: _effectiveHasNewVersion,
                            );
                          },
                        ),
                      ),
                      if (_needBoardSection)
                        ListTile(
                          leading: WcListIcon(Icons.article, pigment: 1),
                          title: Text(I18n.of(context).bulletin_board),
                          onTap: () => Leader.push(
                            context,
                            BoardPage(boardList: _boardList),
                          ),
                        ),
                      Observer(
                        builder: (context) {
                          if (accountStore.now != null)
                            return ListTile(
                              leading: WcListIcon(Icons.arrow_back, pigment: 2),
                              title: Text(I18n.of(context).logout),
                              onTap: () => _showLogoutDialog(context),
                            );
                          else
                            return ListTile(
                              leading: WcListIcon(Icons.arrow_back, pigment: 3),
                              title: Text(I18n.of(context).login),
                              onTap: () => Leader.push(context, LoginPage()),
                            );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future _showLogoutDialog(BuildContext context) async {
    final result = await showWcDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(I18n.of(context).logout),
          actions: <Widget>[
            TextButton(
              child: Text(I18n.of(context).cancel),
              onPressed: () {
                Navigator.of(context).pop("CANCEL");
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
      },
    );
    switch (result) {
      case "OK":
        {
          accountStore.deleteAll();
        }
        break;
      case "CANCEL":
        {}
        break;
    }
  }

  void cleanGlanceData() async {
    GlanceIllustPersistProvider glanceIllustPersistProvider =
        GlanceIllustPersistProvider();
    await glanceIllustPersistProvider.open();
    await glanceIllustPersistProvider.deleteAll();
    await glanceIllustPersistProvider.close();
  }

  bool _needBoardSection = false;
  List<BoardInfo> _boardList = [];

  fetchBoard() async {
    try {
      if (BoardInfo.boardDataLoaded) {
        setState(() {
          _boardList = BoardInfo.boardList;
          _needBoardSection = _boardList.isNotEmpty;
        });
        return;
      }
      final list = await BoardInfo.load();
      setState(() {
        BoardInfo.boardDataLoaded = true;
        _boardList = list;
        _needBoardSection = _boardList.isNotEmpty;
      });
    } catch (e) {}
  }
}
