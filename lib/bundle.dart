import 'dart:io';
import 'dart:convert';
import 'bundle_item.dart';

class Bundle {
  final DateTime lastModified;
  final String locale;
  final String context;
  final String author;
  final Set<BundleItem> items;

  Bundle(
      {DateTime lastModified,
      this.locale,
      this.context,
      this.author,
      this.items = const {}})
      : lastModified = lastModified ?? DateTime.now();

  factory Bundle.fromArb(Map<String, dynamic> arb) {
    final bundleItems = Map.fromEntries(
      arb.entries.where(
        (element) => !element.key.startsWith('@@'),
      ),
    );

    final bundle = Bundle(
      author: arb['@@author'] ?? '',
      context: arb['@@context'] ?? '',
      lastModified: arb['@@last_modified'] == null
          ? DateTime.now()
          : DateTime.parse(arb['@@last_modified']),
      locale: arb['@@locale'] ?? '',
      items: {},
    );

    for (final item in bundleItems.entries) {
      if (item.key.startsWith('@')) continue;

      final name = item.key;
      final value = item.value;
      final options = bundleItems['@$name'] ?? <String, dynamic>{};

      bundle.items.add(BundleItem(
        name,
        value,
        description: options['description'] ?? '',
        placeholders: options['placeholders'] ?? {},
        type: options['type'] ?? '',
      ));
    }

    return bundle;
  }

  factory Bundle.fromTsv(String tsv) {
    final global = tsv.split('\n\n').first.split('\n');
    final messages = tsv.split('\n\n').last.split('\n');

    var author = '';
    var context = '';
    var locale = '';
    var lastModified = DateTime.now();

    for (final pair in global) {
      final key = pair.split('\t').first;
      final value = pair.split('\t').last;

      switch (key) {
        case 'author':
          author = value;
          break;
        case 'context':
          context = value;
          break;
        case 'locale':
          locale = value;
          break;
        case 'last_modified':
          lastModified = DateTime.parse(value);
          break;
      }
    }

    final items = <BundleItem>{};
    final columns = messages.first.split('\t');
    final rows = messages.skip(1);
    final nameIndex = columns.indexOf('name');
    final valueIndex = columns.indexOf('value');
    final descriptionIndex = columns.indexOf('description');
    final placeholdersIndex = columns.indexOf('placeholders');
    final typeIndex = columns.indexOf('type');

    for (final row in rows) {
      final values = row.split('\t');
      final placeholders = values[placeholdersIndex]
          .replaceAll(RegExp(r'\(|\)|\ '), '')
          .split(',');
      final map = <String, dynamic>{};

      if (placeholders.length > 1) {
        map.addAll({for (var element in placeholders) element: {}});
      }

      items.add(BundleItem(
        values[nameIndex],
        values[valueIndex],
        description: values[descriptionIndex],
        placeholders: map,
        type: values[typeIndex],
      ));
    }

    return Bundle(
      author: author,
      context: context,
      locale: locale,
      lastModified: lastModified,
      items: items,
    );
  }

  factory Bundle.fromFile(File file) =>
      Bundle.fromArb(json.decode(file.readAsStringSync()));

  Map<String, dynamic> get arb {
    final _arb = <String, dynamic>{
      '@@last_modified': lastModified.toIso8601String(),
      '@@locale': locale,
      '@@context': context,
      '@@author': author,
    };

    for (final item in items) {
      _arb.addAll(item.arb);
    }

    return _arb;
  }

  String get tsv {
    final globals = 'last_modified\t${lastModified.toIso8601String()}\n'
        'context\t$context\n'
        'locale\t$locale\n'
        'author\t$author\n';
    final divider = '\n';
    final columns = 'name\tvalue\tdescription\tplaceholders\ttype\n';
    final rows = items.map((e) => e.tsv).join('\n');

    return globals + divider + columns + rows;
  }

  void merge(Bundle bundle) {
    // TODO: merge arb values.
  }
}
