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

import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';

class StarIcon extends StatefulWidget {
  final int state;

  const StarIcon({Key? key, required this.state}) : super(key: key);

  @override
  _StarIconState createState() => _StarIconState();
}

class _StarIconState extends State<StarIcon> {
  late int state;

  @override
  void initState() {
    state = widget.state;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant StarIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      setState(() {
        state = widget.state;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      color: Colors.transparent,
      child: _buildData(state),
    );
  }

  Widget _buildData(int state) {
    final tokens = WatercolorTokens.of(context);
    if (tokens != null) return _buildWatercolor(tokens, state);
    switch (state) {
      case 0:
        return WcIcon(
          Icons.favorite_border,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case 1:
        return WcIcon(
          Icons.favorite,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      default:
        return WcIcon(Icons.favorite, color: Colors.red);
    }
  }

  /// Line heart in ink; a liked heart is filled and sits on a pigment bloom.
  Widget _buildWatercolor(WatercolorTokens tokens, int state) {
    final liked = state == 2;
    return Stack(
      alignment: Alignment.center,
      children: [
        PigmentBackdrop(
          color: tokens.pigment(0),
          visible: liked,
          opacity: 0.6,
          shape: PigmentShape.dot,
          bleed: const EdgeInsets.all(7),
          child: const SizedBox(width: 20, height: 20),
        ),
        WcIcon(
          state == 0 ? Icons.favorite_border : Icons.favorite,
          size: 20,
          color: switch (state) {
            0 => tokens.ink,
            1 => tokens.sub,
            _ => tokens.liked,
          },
        ),
      ],
    );
  }
}
