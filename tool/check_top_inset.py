# -*- coding: utf-8 -*-
"""顶部安全区门禁：任何页面内容都不许画进系统状态栏。

判定规则（三条，全部来自 Flutter 的真实布局语义）：

1. `Scaffold` 给 `appBar` 的是 **loose 约束**（`_ScaffoldLayout`：
   `appBarHeight = layoutChild(_ScaffoldSlot.appBar, fullWidthConstraints).height`），
   高度由 appBar 自己决定。标准 `AppBar` 自己把 `MediaQuery.paddingOf(context).top`
   加进高度；所以 `appBar:` 槽位上的 `PlainTopBar` **必须**保持 `primary: true`（默认）。
   → `appBar: PlainTopBar(primary: false)` 即为「内容顶进状态栏」，报错。

2. 放进 `body` 的 `PlainTopBar`（页面自管顶距）**必须**显式 `primary: false`，
   否则 SafeArea 与页面的 `Padding(top: ...)` 叠加 → 双倍下移。
   → 报错。

3. 没有 `appBar` 的 `Scaffold`，其 `body` 首子节点必须自己承担顶部安全区：
   `SafeArea` / `navigationShell`（子页面自带 Scaffold+appBar）/ 显式列进 EXEMPT。
   → 否则报错。

4. **不许再用 Material `AppBar`**（2026-10-14 起）。全库顶栏只有 `PlainTopBar`
   一个实现：Material `AppBar` 的默认命中盒 48×48 / 图标 24 / 前景色走
   `colorScheme` / 自动返回箭头造型，与设计稿的 44×44 / 22 / `inkSecondary`
   全不一致 —— 混用会让同一根顶栏在不同页面高矮胖瘦不同。
   → 报错。

用法：
    python plain/tool/check_top_inset.py            # 人读
    python plain/tool/check_top_inset.py --quiet     # 只报违规，exit 1 可进 CI
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # plain/
LIB = os.path.join(ROOT, "lib")

# 无 appBar 且 body 首子不是 SafeArea / navigationShell 的**已知豁免**。
# key = 相对 lib 的路径，value = 理由（必须写清为什么安全）。
EXEMPT = {
    "features/ledger/presentation/entry_input_page.dart":
        "body 自带 Padding(top: paddingOf(context).top) 自管顶距",
    "features/ledger/presentation/home_shell.dart":
        "大屏分支 body=Row(NavigationRail 内部已 SafeArea) + macOS 窗口自带标题栏",
    "features/ledger/presentation/entry_detail_page.dart":
        "该 Scaffold 是「账单不存在」空态，body=Center 内容居中不贴顶",
}

SAFE_BODY_HEADS = ("SafeArea", "navigationShell")


def paren_block(s, i):
    """i 指向 '(' 的下标，返回配对内部的文本。"""
    depth = 0
    for j in range(i, len(s)):
        if s[j] == "(":
            depth += 1
        elif s[j] == ")":
            depth -= 1
            if depth == 0:
                return s[i + 1:j]
    return s[i:i + 900]


def line_of(s, idx):
    return s.count("\n", 0, idx) + 1


def scan():
    appbar_missing = []      # appBar 槽位传了 primary: false
    body_double = []         # body 里的 PlainTopBar 没关 primary
    naked_scaffold = []      # 无 appBar 且 body 首子无安全区
    material_appbar = []     # 用 Material AppBar（自带状态栏，仅提示）

    for base, dirs, files in os.walk(LIB):
        dirs[:] = [d for d in dirs if d not in (".dart_tool", "build", "generated")]
        for fn in sorted(files):
            if not fn.endswith(".dart"):
                continue
            p = os.path.join(base, fn)
            rel = os.path.relpath(p, LIB).replace(os.sep, "/")
            s = open(p, encoding="utf-8").read()

            # ── 1 / 2：PlainTopBar 的两种槽位 ──
            in_appbar = set()
            for m in re.finditer(r"appBar\s*:\s*(?:const\s+)?PlainTopBar\s*\(", s):
                # 括号在 match 末尾
                in_appbar.add(m.end() - 1)
            for m in re.finditer(r"PlainTopBar\s*\(", s):
                if m.group(0).startswith("appBar"):
                    continue
                i = m.end() - 1
                blk = paren_block(s, i)
                if "super.key" in blk:
                    continue  # 类里的构造函数声明，不是使用点
                is_appbar = i in in_appbar
                if is_appbar:
                    if re.search(r"(^|[^\w.])primary\s*:\s*false", blk):
                        appbar_missing.append("%s:%d" % (rel, line_of(s, m.start())))
                else:
                    if not re.search(r"(^|[^\w.])primary\s*:\s*false", blk):
                        body_double.append("%s:%d" % (rel, line_of(s, m.start())))

            # ── 3：无 appBar 的 Scaffold ──
            for m in re.finditer(r"\bScaffold\s*\(", s):
                blk = paren_block(s, m.end() - 1)
                if re.search(r"(^|[^\w.])appBar\s*:", blk):
                    if re.search(r"(^|[^\w.])appBar\s*:\s*(?:const\s+)?AppBar\s*\(", blk):
                        material_appbar.append("%s:%d" % (rel, line_of(s, m.start())))
                    continue
                head = re.search(r"body\s*:\s*([A-Za-z_][\w.]*)", blk)
                head_name = head.group(1) if head else "?"
                if head_name in SAFE_BODY_HEADS:
                    continue
                if rel in EXEMPT:
                    continue
                naked_scaffold.append(
                    "%s:%d  body=%s" % (rel, line_of(s, m.start()), head_name))

    return appbar_missing, body_double, naked_scaffold, material_appbar


def main():
    quiet = "--quiet" in sys.argv
    bad_ab, bad_body, naked, material = scan()
    failures = len(bad_ab) + len(bad_body) + len(naked) + len(material)

    if not quiet:
        print("顶部安全区门禁")
        print("  规则① appBar 槽位上的 PlainTopBar 必须 primary:true(默认)  "
              "-> 违规 %d" % len(bad_ab))
        for x in bad_ab:
            print("     ! " + x)
        print("  规则② body 里的 PlainTopBar 必须显式 primary:false          "
              "-> 违规 %d" % len(bad_body))
        for x in bad_body:
            print("     ! " + x)
        print("  规则③ 无 appBar 的 Scaffold，body 首子须自带顶部安全区      "
              "-> 违规 %d" % len(naked))
        for x in naked:
            print("     ! " + x)
        print("  规则④ 顶栏统一走 PlainTopBar，禁用 Material AppBar         "
              "-> 违规 %d" % len(material))
        for x in material:
            print("     ! " + x)
        print()
        print("违规合计 %d" % failures)

    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
