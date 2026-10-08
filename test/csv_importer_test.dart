/// CSV importer tests: parsing, date/amount formats, dedup, fingerprint.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/csv_importer.dart';

void main() {
  group('parseCsv', () {
    test('parses simple CSV', () {
      final rows = parseCsv('日期,金额,备注\n2024-01-15,25.00,午餐');
      expect(rows.length, 2);
      expect(rows[0], ['日期', '金额', '备注']);
      expect(rows[1], ['2024-01-15', '25.00', '午餐']);
    });

    test('handles quoted fields with commas', () {
      final rows = parseCsv('日期,金额,备注\n2024-01-15,25.00,"午餐, 麻辣烫"');
      expect(rows[1], ['2024-01-15', '25.00', '午餐, 麻辣烫']);
    });

    test('handles escaped quotes', () {
      final rows = parseCsv('a,b\n"x""y",z');
      expect(rows[1], ['x"y', 'z']);
    });

    test('handles BOM and CRLF', () {
      final rows = parseCsv('\uFEFFa,b\r\n1,2\r\n');
      expect(rows.length, 2);
      expect(rows[0], ['a', 'b']);
    });

    test('skips empty lines', () {
      final rows = parseCsv('a,b\n1,2\n\n3,4\n');
      expect(rows.length, 3);
    });
  });

  group('parseDate', () {
    test('parses ISO format', () {
      final d = parseDate('2024-01-15');
      expect(d, DateTime(2024, 1, 15));
    });

    test('parses slash format', () {
      final d = parseDate('2024/01/15');
      expect(d, DateTime(2024, 1, 15));
    });

    test('parses compact format', () {
      final d = parseDate('20240115');
      expect(d, DateTime(2024, 1, 15));
    });

    test('parses Chinese format', () {
      final d = parseDate('2024年1月15日');
      expect(d, DateTime(2024, 1, 15));
    });

    test('rejects garbage', () {
      expect(parseDate('hello'), isNull);
      expect(parseDate(''), isNull);
    });

    test('rejects invalid month', () {
      expect(parseDate('2024-13-01'), isNull);
    });
  });

  group('parseAmountCents', () {
    test('parses plain decimal', () {
      expect(parseAmountCents('25.00'), 2500);
      expect(parseAmountCents('25'), 2500);
      expect(parseAmountCents('25.5'), 2550);
    });

    test('parses with currency symbols', () {
      expect(parseAmountCents('¥25.00'), 2500);
      expect(parseAmountCents('￥25'), 2500);
      expect(parseAmountCents('25.00元'), 2500);
    });

    test('parses negative', () {
      expect(parseAmountCents('-25.00'), -2500);
    });

    test('parses parentheses as negative', () {
      expect(parseAmountCents('(25.00)'), -2500);
    });

    test('strips commas', () {
      expect(parseAmountCents('1,234.56'), 123456);
    });

    test('rejects garbage', () {
      expect(parseAmountCents('abc'), isNull);
      expect(parseAmountCents(''), isNull);
      expect(parseAmountCents('0'), 0);
    });
  });

  group('fingerprint and label', () {
    test('fingerprint uses date|amount|label', () {
      final fp = buildFingerprint(date: DateTime(2024, 1, 15), amountCents: 2500, label: '午餐');
      expect(fp, '2024-01-15|2500|午餐');
    });

    test('fingerprint uses abs amount', () {
      final fp = buildFingerprint(date: DateTime(2024, 1, 15), amountCents: -2500, label: '午餐');
      expect(fp, '2024-01-15|2500|午餐');
    });

    test('composeLabel combines merchant and note', () {
      expect(composeLabel(merchant: '星巴克', note: '拿铁'), '星巴克 拿铁');
      expect(composeLabel(merchant: '星巴克', note: null), '星巴克');
      expect(composeLabel(merchant: null, note: '拿铁'), '拿铁');
      expect(composeLabel(merchant: null, note: null), '');
    });
  });

  group('parseRows', () {
    const mapping = CsvColumnMapping(dateCol: 0, amountCol: 1, categoryCol: 2, noteCol: 3);

    test('parses valid rows', () {
      final rows = parseCsv(
        '日期,金额,分类,备注\n'
        '2024-01-15,25.00,餐饮,午餐\n'
        '2024-01-16,30.00,交通,打车\n',
      );
      final result = parseRows(rows, mapping);
      expect(result.entries.length, 2);
      expect(result.errors, isEmpty);
      expect(result.entries[0].amountCents, 2500);
      expect(result.entries[0].categoryName, '餐饮');
      expect(result.entries[0].note, '午餐');
    });

    test('reports unparseable date', () {
      final rows = parseCsv('日期,金额\nbad,25.00\n');
      final result = parseRows(rows, const CsvColumnMapping(dateCol: 0, amountCol: 1));
      expect(result.entries, isEmpty);
      expect(result.errors.length, 1);
    });

    test('reports unparseable amount', () {
      final rows = parseCsv('日期,金额\n2024-01-15,abc\n');
      final result = parseRows(rows, const CsvColumnMapping(dateCol: 0, amountCol: 1));
      expect(result.entries, isEmpty);
      expect(result.errors.length, 1);
    });

    test('skips empty rows', () {
      final rows = parseCsv('日期,金额\n2024-01-15,25.00\n,\n2024-01-16,30.00\n');
      final result = parseRows(rows, const CsvColumnMapping(dateCol: 0, amountCol: 1));
      expect(result.entries.length, 2);
    });
  });

  group('dedupEntries', () {
    ParsedEntry make(String date, int cents, String label) {
      return ParsedEntry(
        occurredAt: DateTime.parse(date),
        amountCents: cents,
        type: EntryType.expense,
        fingerprint: buildFingerprint(date: DateTime.parse(date), amountCents: cents, label: label),
      );
    }

    test('removes duplicates within batch', () {
      final entries = [
        make('2024-01-15', 2500, '午餐'),
        make('2024-01-15', 2500, '午餐'),
        make('2024-01-16', 3000, '打车'),
      ];
      final result = dedupEntries(entries, {});
      expect(result.unique.length, 2);
      expect(result.dedupedCount, 1);
    });

    test('removes duplicates against existing', () {
      final entries = [
        make('2024-01-15', 2500, '午餐'),
        make('2024-01-16', 3000, '打车'),
      ];
      final existing = {'2024-01-15|2500|午餐'};
      final result = dedupEntries(entries, existing);
      expect(result.unique.length, 1);
      expect(result.dedupedCount, 1);
      expect(result.unique.first.fingerprint, '2024-01-16|3000|打车');
    });
  });
}
