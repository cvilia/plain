/// STORY-5.3 首页卡片自定义：拖拽排序 + 显示/隐藏 + 预设布局。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/settings/home_layout_prefs.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_toast.dart';

class HomeLayoutPage extends ConsumerStatefulWidget {
  const HomeLayoutPage({super.key});

  @override
  ConsumerState<HomeLayoutPage> createState() => _HomeLayoutPageState();
}

class _HomeLayoutPageState extends ConsumerState<HomeLayoutPage> {
  List<String> _order = [];
  Set<String> _hidden = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await loadHomeCardOrder();
    final hidden = await loadHomeCardHidden();
    if (!mounted) return;
    setState(() {
      _order = order;
      _hidden = hidden;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await saveHomeLayout(order: _order, hidden: _hidden);
    if (mounted) {
      ref.read(dataInvalidationProvider.notifier).bumpHomeLayout();
      showAppToast(context, '布局已保存');
    }
  }

  Future<void> _applyPreset(List<HomeCardId> preset) async {
    await applyHomePreset(preset);
    await _load();
    if (mounted) {
      ref.read(dataInvalidationProvider.notifier).bumpHomeLayout();
      showAppToast(context, '已切换预设');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页卡片'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                // 预设布局
                Text('预设布局', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary, letterSpacing: 2)),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  children: [
                    ActionChip(label: const Text('极简'), onPressed: () => _applyPreset(HomeLayoutPresets.minimal)),
                    ActionChip(label: const Text('标准'), onPressed: () => _applyPreset(HomeLayoutPresets.standard)),
                    ActionChip(label: const Text('全景'), onPressed: () => _applyPreset(HomeLayoutPresets.panoramic)),
                  ],
                ),
                const SizedBox(height: Spacing.xl),
                Text('卡片排序与显示', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary, letterSpacing: 2)),
                const SizedBox(height: Spacing.sm),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _order.length,
                  onReorderItem: (oldIdx, newIdx) {
                    setState(() {
                      final item = _order.removeAt(oldIdx);
                      _order.insert(newIdx, item);
                    });
                  },
                  itemBuilder: (ctx, i) {
                    final id = _order[i];
                    final card = HomeCardId.values.firstWhere((c) => c.id == id, orElse: () => HomeCardId.recentEntries);
                    final isHidden = _hidden.contains(id);
                    return ListTile(
                      key: ValueKey(id),
                      leading: Icon(isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 22, color: isHidden ? context.colors.inkTertiary : context.colors.primary),
                      title: Text(card.label, style: TextStyle(fontSize: 15, color: isHidden ? context.colors.inkTertiary : null)),
                      trailing: const Icon(Icons.drag_handle, size: 20),
                      onTap: () {
                        setState(() {
                          if (isHidden) {
                            _hidden.remove(id);
                          } else {
                            _hidden.add(id);
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: Spacing.xl),
                Text(
                  '长按拖拽调整顺序，点击切换显示/隐藏。\n「最近账单」为首页主体，建议保留。',
                  style: TextStyle(fontSize: 11, color: context.colors.inkTertiary, height: 1.6),
                ),
              ],
            ),
    );
  }
}
