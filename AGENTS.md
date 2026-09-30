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

## 测试

```bat
cd /d C:\Users\lizhenyu\WorkBuddy\Dev\PlainApp\plain
set "PROGRAMFILES(X86)=C:\Program Files (x86)"
C:\Users\lizhenyu\flutter\bin\flutter.bat test
```

## 构建（Android）

Flavor：`dev`（`com.cvilia.plain.dev`，模拟器调试）/ `prod`（`com.cvilia.plain`，正式包）。
产物命名：`Plain-{versionName}-{flavor}-{buildType}.apk`，如 `Plain-1.0.0-prod-release.apk`。

**ABI 不要写进 `ndk.abiFilters`**（会和 Flutter `--split-per-abi` 的 `splits.abi` 冲突）。用 `--target-platform` 控制：`android-arm,android-x64` = armeabi-v7a + x86_64（排除 arm64-v8a）。

```bat
:: 调试装模拟器
flutter run --flavor dev

:: 正式包（armeabi-v7a + x86_64）
flutter build apk --flavor prod --release --target-platform android-arm,android-x64
flutter build appbundle --flavor prod --release --target-platform android-arm,android-x64

:: 按 ABI 拆分
flutter build apk --flavor prod --release --split-per-abi --target-platform android-arm,android-x64
```

签名：`android/key.properties` + `android/app/upload-keystore.jks`（均已 gitignore）。**密钥与口令务必备份，丢失无法更新应用。**

## 下一步（V1.1 余量）

1. 回收站 UI（软删除已就绪）
2. CSV / 竞品导入
3. WebDAV
