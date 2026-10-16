/// STORY-8.2 AC2 的一致性鉴权：**只读成员不得新增或改动账单**。
///
/// 记账页保存点已经拦过一次（控制器里），但写账单的入口不止那一个：
/// CSV 导入、回收站恢复、对账调整、拆分都会产生/改动账单 —— 只拦保存点
/// 等于「只读成员可以用导入绕过去」（audit 2026-10-15 发现）。
/// 每个入口在动手前调一次本函数。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/design_system/app_toast.dart';

/// 返回 false 表示已提示用户「无权限」，调用方直接 return。
Future<bool> guardCanWriteLedger(BuildContext context, WidgetRef ref) async {
  final deps = ref.read(appDependenciesProvider);
  // 没有成员记录（单人本地使用）时 canWrite 为 true
  if (await deps.memberService.canWrite(deps.bookId)) return true;
  if (context.mounted) {
    showAppToast(context, '你是「只读」成员，没有记账权限');
  }
  return false;
}
