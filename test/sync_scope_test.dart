/// STORY-8.1 AC4/AC5：同步范围。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/services/sync_scope.dart';

void main() {
  test('theme prefs are local-only (AC4)', () {
    expect(isLocalOnlySetting('pref.theme.id'), true);
    expect(isSyncedSetting('pref.theme.id'), false);
    expect(isSyncedSetting('pref.month_start_day'), true);
    expect(isSyncedSetting('pref.hide_amounts'), true);
  });

  test('filterSyncPayload strips theme fields (AC5)', () {
    final p = filterSyncPayload({
      'pref.month_start_day': '10',
      'pref.theme.id': 'qingci',
      'themeId': 'qingci',
      'themeMode': 'dark',
      'homeCardLayout': 'x',
      'note': 'keep',
    });
    expect(p.containsKey('pref.month_start_day'), true);
    expect(p.containsKey('pref.theme.id'), false);
    expect(p.containsKey('themeId'), false);
    expect(p.containsKey('themeMode'), false);
    expect(p.containsKey('homeCardLayout'), false);
    expect(p['note'], 'keep');
  });

  test('synced entity types include savings and rules', () {
    expect(isSyncedEntityType('savings_goal'), true);
    expect(isSyncedEntityType('rule'), true);
    expect(isSyncedEntityType('theme'), false);
  });
}
