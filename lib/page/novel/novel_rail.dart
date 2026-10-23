/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    10| *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <http://www.gnu.org/licenses/>.
 */
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/hello/android_hello_page.dart';
import 'package:pixez/page/hello/hello_page.dart';
import 'package:pixez/page/hello/setting/setting_page.dart';
import 'package:pixez/page/novel/new/novel_new_page.dart';
import 'package:pixez/page/novel/novel_rail_layout.dart';
import 'package:pixez/page/novel/rank/novel_rank_page.dart';
import 'package:pixez/utils/haptic_util.dart';
import 'package:pixez/page/novel/recom/novel_recom_page.dart';
import 'package:pixez/page/novel/search/novel_search_page.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/palette_bar.dart';

void openNovelRail(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).pushReplacement(MaterialPageRoute(builder: (context) => NovelRail()));
}

class NovelRail extends StatefulWidget {
  @override
  _NovelRailState createState() => _NovelRailState();
}

class _NovelRailState extends State<NovelRail> {
  int selectedIndex = 0;
  DateTime? _preTime;
  PageController? _pageController;
  final Map<int, Widget> _lazyPages = <int, Widget>{};

  @override
  void initState() {
    if (novelRailUsesSwipeablePages()) {
      _pageController = PageController();
    }
    Constants.type = 1;
    fetcher.context = context;
    super.initState();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Widget _pageFor(int index) {
    return _lazyPages.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return NovelRecomPage();
        case 1:
          return NovelRankPage();
        case 2:
          return NovelNewPage();
        case 3:
          return NovelSearchPage();
        default:
          return SettingPage();
      }
    });
  }

  Widget _buildPages() {
    _pageFor(selectedIndex);
    if (novelRailUsesSwipeablePages()) {
      return PageView.builder(
        itemCount: 5,
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return _pageFor(index);
        },
      );
    }
    return Stack(
      children: [
        for (final entry in _lazyPages.entries)
          Offstage(
            offstage: entry.key != selectedIndex,
            child: TickerMode(
              enabled: entry.key == selectedIndex,
              child: entry.value,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        userSetting.setAnimContainer(!userSetting.animContainer);
        if (didPop) return;
        if (!userSetting.isReturnAgainToExit) {
          return;
        }
        if (_preTime == null ||
            DateTime.now().difference(_preTime!) > Duration(seconds: 2)) {
          setState(() {
            _preTime = DateTime.now();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 1),
              content: Text(I18n.of(context).return_again_to_exit),
            ),
          );
        }
      },
      canPop:
          !userSetting.isReturnAgainToExit ||
          _preTime != null &&
              DateTime.now().difference(_preTime!) <= Duration(seconds: 2),
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => Platform.isIOS || Platform.isMacOS
                    ? HelloPage()
                    : AndroidHelloPage(),
              ),
            );
          },
          child: WcIcon(Icons.picture_in_picture),
        ),
        bottomNavigationBar: _buildNavigationBar(context),
        body: _buildPages(),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    void select(int index) {
      HapticUtil.selectionClick();
      if (this.selectedIndex == index) {
        topStore.setTop("${index + 1}00");
      }
      setState(() {
        this.selectedIndex = index;
      });
      if (_pageController?.hasClients == true) {
        _pageController!.jumpToPage(index);
      }
    }

    if (WatercolorTokens.of(context) != null) {
      return PaletteBar(
        items: [
          PaletteBarItem(icon: Icons.home, label: I18n.of(context).home),
          PaletteBarItem(icon: Icons.leaderboard, label: I18n.of(context).rank),
          PaletteBarItem(icon: Icons.favorite, label: I18n.of(context).news),
          PaletteBarItem(icon: Icons.search, label: I18n.of(context).search),
          PaletteBarItem(icon: Icons.settings, label: I18n.of(context).setting),
        ],
        selectedIndex: selectedIndex,
        onSelected: select,
      );
    }

    return NavigationBar(
      destinations: [
        NavigationDestination(
          icon: WcIcon(Icons.home),
          label: I18n.of(context).home,
        ),
        NavigationDestination(
          icon: WcIcon(Icons.leaderboard),
          label: I18n.of(context).rank,
        ),
        NavigationDestination(
          icon: WcIcon(Icons.favorite),
          label: I18n.of(context).news,
        ),
        NavigationDestination(
          icon: WcIcon(Icons.search),
          label: I18n.of(context).search,
        ),
        NavigationDestination(
          icon: WcIcon(Icons.settings),
          label: I18n.of(context).setting,
        ),
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: select,
    );
  }
}
