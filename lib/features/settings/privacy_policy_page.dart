/// 隐私政策（STORY-4.3 / F8.3 产品宪法）。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const List<(String, String)> _sections = [
    (
      '无广告、无开屏、无金融导流',
      '素记不展示广告，没有开屏广告，也不会向你推荐贷款、理财等金融产品。'
    ),
    (
      '数据默认本地',
      '账单、分类、账户等数据默认只保存在你的设备上。未登录即可使用全部记账功能。'
    ),
    (
      '数据库加密',
      '本地数据库使用 SQLCipher 全库加密，密钥保存在系统安全区（Keychain / Keystore），不上传、不同步密钥。'
    ),
    (
      '不申请无关权限',
      '只申请与功能直接相关的权限（如通知、相册）。短信自动记账等敏感能力为可选且需你主动开启。'
    ),
    (
      '不做用户画像',
      '不采集设备指纹用于广告画像，不把账单数据用于任何第三方分析或变现。'
    ),
    (
      '备份与同步',
      '备份文件由你自行保管或分享。云同步（若启用）只传输记账数据本身；主题与外观等本地偏好不同步。'
    ),
    (
      '你的数据你做主',
      '支持导出与删除。卸载应用会删除本地数据；备份文件请自行妥善保存。'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私政策')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          Text(
            '素记 · 隐私承诺',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '更新日期：2026-10',
            style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
          ),
          const SizedBox(height: Spacing.lg),
          for (final (title, body) in _sections) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              body,
              style: TextStyle(fontSize: 14, height: 1.6, color: context.colors.inkSecondary),
            ),
            const SizedBox(height: Spacing.lg),
          ],
        ],
      ),
    );
  }
}
