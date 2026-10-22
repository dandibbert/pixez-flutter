"""Copies the MingCute icons the watercolor style uses into assets/.

MingCute (https://www.mingcute.com) is licensed under Apache-2.0. Get the
SVGs from the npm package and point this script at its `package` folder:

    npm pack mingcute_icon && tar xzf mingcute_icon-*.tgz
    python3 tool/import_mingcute_icons.py package

Each icon keeps its line and fill variant. The transparent sizing path is
dropped and the paint switched to black, so the app can tint it with a
color filter.
"""

import pathlib
import re
import shutil
import sys

# Keep in sync with lib/watercolor/mingcute.dart.
NAMES = """
add arrow_down arrow_left arrow_up back book_2 bookmark calendar check
check_circle close close_circle comment copy_2 delete_2 down down_small
download_2 edit_2 external_link eye_2 eye_close filter folder folder_open
font forbid_circle fullscreen fullscreen_exit group hashtag headphone heart
history home_4 information layers left line_height link list_check lock mail
more_1 more_2 news palette paste pause pause_circle pic play play_circle
refresh_2 right search send_plane settings_3 settings_6 share_2
skip_forward skip_previous sort_descending star stop sun translate_2 trophy
time up user_3 volume warning
""".split()

SIZING_PATH = re.compile(r'<path d="M24 0v24H0V0(?:h24Z|z)[^"]*"/>')


def main() -> None:
    package = pathlib.Path(sys.argv[1])
    out = pathlib.Path(__file__).resolve().parent.parent / "assets/icons/mingcute"
    out.mkdir(parents=True, exist_ok=True)
    svgs = {p.name: p for p in (package / "svg").rglob("*.svg")}
    for name in NAMES:
        for variant in ("line", "fill"):
            source = svgs[f"{name}_{variant}.svg"]
            svg = SIZING_PATH.sub("", source.read_text())
            svg = re.sub(r'fill="#[0-9A-Fa-f]{3,8}"', 'fill="#000"', svg)
            (out / f"{name}_{variant}.svg").write_text(svg)
    shutil.copy(package / "LICENSE", out / "LICENSE.txt")
    print(f"copied {len(NAMES) * 2} icons to {out}")


if __name__ == "__main__":
    main()
