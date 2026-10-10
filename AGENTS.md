# AGENTS.md — 素记 Plain

## 绝对路径（与对话工作区无关）

- 工程：`C:\Users\lizhenyu\WorkBuddy\Dev\PlainApp\plain`
- 文档：`C:\Users\lizhenyu\WorkBuddy\Dev\PlainApp\`（01–10 + HANDOFF.md）
- **新会话先读** `C:\Users\lizhenyu\WorkBuddy\Dev\PlainApp\HANDOFF.md`

## 规则

- 中文交流
- 不要执行 flutter build / 发布；测试可以跑
- 不降级依赖
- 产品名「素记/Plain」
- 断点常量只在 `lib/app/breakpoints.dart`
- 金额 int64 分，禁 double
- 含中文文件用 Write/Edit，禁 PowerShell 批量替换
- FAB 必须 heroTag

## 数据刷新（强制架构，后续开发一律遵守）

**核心：写→bump，读→watch。禁止靠「返回上一页时手动 refresh()」。**

```dart
// 1) 写侧：任何本地入库后 bump 对应 scope
ref.invalidateData.bumpEntryMutated();      // 记账增删改/导入/回收站恢复
ref.invalidateData.bumpCategoriesMutated(); // 分类增删改/合并
ref.invalidateData.bumpAccountsMutated();   // 账户增删改/对账
ref.invalidateData.bumpBudgetMutated();     // 预算规则
ref.invalidateData.bumpRecurringMutated();  // 周期记账

// 2) 读侧：缓存型读模型必须 watch 版本
final xProvider = FutureProvider<T>((ref) async {
  ref.watch(ledgerVersionProvider); // 变更自动重取
  return load();
});

// 分页 Notifier 则 listen：
ref.listen(ledgerVersionProvider, (_, __) => refresh());
```

| Scope | 何时 bump | 谁 watch |
|---|---|---|
| ledger | 流水增删改/导入/恢复 | 流水列表、报表、预算条 |
| accounts | 账户/对账 | 资产页 |
| categories | 分类管理 | 分类选择器、记一笔 |
| budget | 预算规则 | 预算条、预算页 |
| recurring | 周期规则 | 周期页 |
| theme | 主题/外观 | 一切读 BrandColors 且常驻的 UI |

**主题取色**：`BrandColors` 是静态门面，不会触发重建。常驻 Widget（壳 FAB、Tab 页）的 `build()` 里**必须**调 `watchBrandTheme(ref)`。

**禁止**：页面 pop 后手动 `otherController.refresh()`；用 `ref.invalidate` 跨模块清别人的 provider。

实现：`lib/core/refresh/data_invalidation.dart`。

## 测试

```bat
cd /d C:\Users\lizhenyu\WorkBuddy\Dev\PlainApp\plain
set "PROGRAMFILES(X86)=C:\Program Files (x86)"
C:\Users\lizhenyu\flutter\bin\flutter.bat test
```

## 构建（Android）

Flavor：`dev`（`com.cvilia.plain.dev`，模拟器调试）/ `prod`（`com.cvilia.plain`，正式包）。
产物命名：`Plain-{versionName}-{flavor}-{buildType}.apk`，如 `Plain-1.0.0-prod-release.apk`。

**ABI 不要写进 `ndk.abiFilters`**（会和 Flutter `--split-per-abi` 的 `splits.abi` 冲突）。用 `--target-platform` 控制：
`android-arm,android-arm64,android-x64` = armeabi-v7a + **arm64-v8a** + x86_64。
arm64-v8a **必须包含**，否则 HarmonyOS / 部分 64 位机型启动即崩
（`libflutter.so is 32-bit instead of 64-bit`）。旧写法 `android-arm,android-x64` = armeabi-v7a + x86_64（排除 arm64-v8a）。

```bat
:: 调试装模拟器
flutter run --flavor dev

:: 正式包（armeabi-v7a + arm64-v8a + x86_64）
flutter build apk --flavor prod --release --target-platform android-arm,android-arm64,android-x64
flutter build appbundle --flavor prod --release --target-platform android-arm,android-arm64,android-x64

:: 按 ABI 拆分
flutter build apk --flavor prod --release --split-per-abi --target-platform android-arm,android-arm64,android-x64
```

**Android Studio Run**：必须带 flavor，否则 Flutter 找 `app-debug.apk` 会报
`Gradle build failed to produce an .apk file`。已在 `.idea/runConfigurations/` 预置
`main.dart (dev)` / `main.dart (prod)`。若自己改 Run Configuration，Additional args 填 `--flavor dev`。

签名：`android/key.properties` + `android/app/upload-keystore.jks`（均已 gitignore）。**密钥与口令务必备份，丢失无法更新应用。**

## 下一步（V2.0 余量）

1. 回收站 UI（软删除已就绪）
2. CSV / 竞品导入
3. WebDAV
