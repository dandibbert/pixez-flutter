import 'package:material_ui/material_ui.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/rank/novel_rank_page.dart';
import 'package:pixez/page/novel/recom/novel_recom_page.dart';
import 'package:pixez/page/novel/search/novel_search_page.dart';

class NovelHomePage extends StatefulWidget {
  const NovelHomePage({super.key});

  @override
  State<NovelHomePage> createState() => _NovelHomePageState();
}

class _NovelHomePageState extends State<NovelHomePage> {
  @override
  void initState() {
    Constants.type = 1;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.novel),
        actions: [
          IconButton(
            tooltip: i18n.rank,
            icon: const Icon(Icons.leaderboard),
            onPressed: () => Leader.push(
              context,
              NovelRankPage(),
              icon: const Icon(Icons.leaderboard),
              title: Text(i18n.rank),
            ),
          ),
          IconButton(
            tooltip: i18n.search,
            icon: const Icon(Icons.search),
            onPressed: () => Leader.push(
              context,
              NovelSearchPage(),
              icon: const Icon(Icons.search),
              title: Text(i18n.search),
            ),
          ),
        ],
      ),
      body: const NovelRecomPage(showHeader: false),
    );
  }
}
