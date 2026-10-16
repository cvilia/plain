"""【已废弃】旧版「生成 CustomPaint 图标」脚本，保留仅为防止误用。

不要再跑这个脚本。它属于**路线 A**（把 SVG path 在构建期展开成绝对坐标、写进
`IconOp` 元组、配 `CustomPaint` 手绘，并把 `size` 写死 24），已被**路线 B** 取代：

    路线 B：PlainIcon 用 `SvgPicture.asset('assets/icons/ic_*.svg')` 运行时加载，
            `size` 缺省跟随 `IconTheme.of(context).size`（与 `Icon` 语义一致）。

当前生成的 Dart 文件是 `plain/lib/design_system/plain_icons_v3.dart`，由
`plain/tool/gen_icons_abs.py` 产出。改图标请走三步：

    python redesign-v3/_build/gen_icons.py            # 1. 作图（唯一权威源）
    python plain/tool/import_icons_to_assets.py       # 2. 同步 SVG 到 assets/
    python plain/tool/gen_icons_abs.py                # 3. 重新生成 Dart 绑定

本文件如果被执行，会直接退出并报错，不做任何写盘。
"""
import sys

MESSAGE = (
    "gen_plain_icons_v3.py 已废弃（路线 A：CustomPaint 手绘 + size 写死 24）。\n"
    "图标 Dart 绑定改由 plain/tool/gen_icons_abs.py（路线 B：flutter_svg）生成。\n"
    "正确顺序：\n"
    "  python redesign-v3/_build/gen_icons.py\n"
    "  python plain/tool/import_icons_to_assets.py\n"
    "  python plain/tool/gen_icons_abs.py\n"
)


def main() -> int:
    print(MESSAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
