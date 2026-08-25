/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
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
import 'package:pixez/page/novel/rank/novel_rank_page.dart';
import 'package:pixez/page/novel/novel_shell_theme.dart';
import 'package:pixez/utils/haptic_util.dart';
import 'package:pixez/page/novel/recom/novel_recom_page.dart';
import 'package:pixez/page/novel/search/novel_search_page.dart';

void openNovelRail(BuildContext context) {
  final route = MaterialPageRoute(builder: (_) => const NovelRail());
  final navigator = Navigator.of(context, rootNavigator: true);
  // Replacing the whole app on desktop/macOS leaves PopScope as the root
  // route and can spin the navigator. Push keeps HelloPage underneath.
  if (Platform.isAndroid) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
}

class NovelRail extends StatefulWidget {
  const NovelRail({super.key});

  @override
  _NovelRailState createState() => _NovelRailState();
}

class _NovelRailState extends State<NovelRail> {
  int selectedIndex = 0;
  DateTime? _preTime;
  late final List<Widget> _pageList;
  late PageController _pageController;

  @override
  void initState() {
    _pageList = [
      NovelRecomPage(),
      NovelRankPage(),
      NovelNewPage(),
      NovelSearchPage(),
      SettingPage(),
    ];
    _pageController = PageController();
    Constants.type = 1;
    fetcher.context = context;
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => Platform.isIOS || Platform.isMacOS
            ? HelloPage()
            : AndroidHelloPage(),
      ),
    );
  }

  void _selectIndex(int index) {
    HapticUtil.selectionClick();
    if (selectedIndex == index) {
      topStore.setTop("${index + 1}00");
    }
    setState(() {
      selectedIndex = index;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > constraints.maxHeight;
        return PopScope(
          canPop: !userSetting.isReturnAgainToExit ||
              _preTime != null &&
                  DateTime.now().difference(_preTime!) <=
                      const Duration(seconds: 2),
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            if (!userSetting.isReturnAgainToExit) {
              return;
            }
            if (_preTime == null ||
                DateTime.now().difference(_preTime!) >
                    const Duration(seconds: 2)) {
              setState(() {
                _preTime = DateTime.now();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text(I18n.of(context).return_again_to_exit),
                ),
              );
            }
          },
          child: Scaffold(
            floatingActionButton: wide
                ? null
                : FloatingActionButton(
                    onPressed: _goHome,
                    child: const Icon(Icons.picture_in_picture),
                  ),
            bottomNavigationBar: wide ? null : _buildNavigationBar(context),
            body: Row(
              children: [
                if (wide) ..._buildRail(context),
                Expanded(
                  child: PageView.builder(
                    itemCount: _pageList.length,
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        selectedIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _pageList[index];
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return Theme(
      data: applyNovelShellTheme(Theme.of(context)),
      child: content,
    );
  }

  List<Widget> _buildRail(BuildContext context) {
    return [
      NavigationRail(
        selectedIndex: selectedIndex,
        labelType: NavigationRailLabelType.all,
        leading: IconButton(
          tooltip: I18n.of(context).home,
          icon: const Icon(Icons.arrow_back),
          onPressed: _goHome,
        ),
        onDestinationSelected: _selectIndex,
        destinations: [
          NavigationRailDestination(
            icon: const Icon(Icons.home),
            label: Text(I18n.of(context).home),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.leaderboard),
            label: Text(I18n.of(context).rank),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.favorite),
            label: Text(I18n.of(context).news),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.search),
            label: Text(I18n.of(context).search),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.settings),
            label: Text(I18n.of(context).setting),
          ),
        ],
      ),
      const VerticalDivider(thickness: 1, width: 1),
    ];
  }

  NavigationBar _buildNavigationBar(BuildContext context) {
    return NavigationBar(
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home),
          label: I18n.of(context).home,
        ),
        NavigationDestination(
          icon: const Icon(Icons.leaderboard),
          label: I18n.of(context).rank,
        ),
        NavigationDestination(
          icon: const Icon(Icons.favorite),
          label: I18n.of(context).news,
        ),
        NavigationDestination(
          icon: const Icon(Icons.search),
          label: I18n.of(context).search,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings),
          label: I18n.of(context).setting,
        ),
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: _selectIndex,
    );
  }
}
