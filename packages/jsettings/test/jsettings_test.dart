import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jsettings/jsettings.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'mock_io.dart';

void main() {
  test('read non-existent file', () async {
    final settings = JSettings('non-existent.json');
    expect(settings.path, 'non-existent.json');

    final file = MockFile('non-existent.json');
    when(file.existsSync()).thenReturn(false);

    await IOOverrides.runZoned(() async {
      expect(settings.getKeys(), isEmpty);
      expect(settings.getValues(), isEmpty);
      expect(settings.hasValue('key'), isFalse);
      expect(settings.getValue('key'), isNull);
      expect(settings.getBool('key'), isNull);
      expect(settings.getInt('key'), isNull);
      expect(settings.getDouble('key'), isNull);
      expect(settings.getString('key'), isNull);
      expect(settings.getList('key'), isNull);
      expect(settings.getMap('key'), isNull);
    }, createFile: (path) {
      expect(path, file.path);
      return file;
    });

    verify(file.existsSync()).called(1);
    verifyNever(file.readAsStringSync());
  });

  test('read existent file', () async {
    final settings = JSettings('existing.json');
    expect(settings.path, 'existing.json');

    const values = {
      'b': true,
      'i': 123,
      'd': 123.456,
      's': 'abc',
      'l': ['a', 'b', 'c'],
      'm': {'a': 1, 'b': 2, 'c': 3},
    };

    final file = MockFile('existing.json');
    when(file.existsSync()).thenReturn(true);
    when(file.lastModifiedSync()).thenReturn(unixTime(0));
    when(file.readAsStringSync()).thenReturn(jsonEncode(values));

    await IOOverrides.runZoned(() async {
      expect(settings.getKeys(), unorderedEquals(values.keys));
      expect(settings.getValues(), values);
      expect(settings.hasValue('x'), isFalse);
      expect(settings.hasValue('b'), isTrue);
      expect(settings.hasValue('i'), isTrue);
      expect(settings.hasValue('d'), isTrue);
      expect(settings.hasValue('s'), isTrue);
      expect(settings.hasValue('l'), isTrue);
      expect(settings.hasValue('m'), isTrue);
      expect(settings.getValue('x'), isNull);
      expect(settings.getValue('b'), values['b']);
      expect(settings.getValue('i'), values['i']);
      expect(settings.getValue('d'), values['d']);
      expect(settings.getValue('s'), values['s']);
      expect(settings.getValue('l'), values['l']);
      expect(settings.getValue('m'), values['m']);
      expect(settings.getBool('b'),
          isA<bool>().having((v) => v, 'bool', values['b']));
      expect(settings.getInt('i'),
          isA<int>().having((v) => v, 'int', values['i']));
      expect(settings.getDouble('d'),
          isA<double>().having((v) => v, 'double', values['d']));
      expect(settings.getString('s'),
          isA<String>().having((v) => v, 'string', values['s']));
      expect(settings.getList('l'),
          isA<List>().having((v) => v, 'list', values['l']));
      expect(settings.getMap('m'),
          isA<Map>().having((v) => v, 'map', values['m']));
    }, createFile: (path) {
      expect(path, file.path);
      return file;
    });

    verify(file.existsSync()).called(1);
    verify(file.readAsStringSync()).called(1);
  });

  test('read broken formatting', () async {
    final settings = JSettings('broken.json');
    expect(settings.path, 'broken.json');

    final file = MockFile('broken.json');
    when(file.existsSync()).thenReturn(true);
    when(file.lastModifiedSync()).thenReturn(unixTime(0));
    when(file.readAsStringSync()).thenReturn('broken');

    await IOOverrides.runZoned(() async {
      expect(settings.getKeys(), isEmpty);
      expect(settings.getValues(), isEmpty);
      expect(settings.hasValue('x'), isFalse);
      expect(settings.getValue('x'), isNull);
    }, createFile: (path) {
      expect(path, file.path);
      return file;
    });

    verify(file.existsSync()).called(1);
    verify(file.readAsStringSync()).called(1);
  });

  test('write non-existent file', () async {
    final settings = JSettings('non-existent.json');
    expect(settings.path, 'non-existent.json');

    final file = MockFile('non-existent.json');
    when(file.existsSync()).thenReturn(false);
    when(file.writeAsString(any)).thenAnswer((i) async => file);

    await IOOverrides.runZoned(() async {
      await settings.setValue('key', 'value');
    }, createFile: (path) {
      expect(path, file.path);
      return file;
    });

    verify(file.existsSync()).called(isPositive);
    verify(file.createSync(recursive: true)).called(1);
    verify(file.writeAsString('''
{
  "key": "value"
}''')).called(1);
  });

  test('write existing file', () async {
    final settings = JSettings('existing.json');
    expect(settings.path, 'existing.json');

    final file = MockFile('existing.json');
    when(file.existsSync()).thenReturn(true);
    when(file.lastModifiedSync()).thenReturn(unixTime(0));
    when(file.readAsStringSync()).thenReturn('{"key1":"value1"}');
    when(file.writeAsString(any)).thenAnswer((i) async => file);
    when(file.writeAsString(any)).thenAnswer((i) async => file);

    await IOOverrides.runZoned(() async {
      await settings.setValue('key2', 'value2');
    }, createFile: (path) {
      expect(path, file.path);
      return file;
    });

    verify(file.existsSync()).called(isPositive);
    verifyNever(file.createSync(recursive: true));
    verify(file.writeAsString('''
{
  "key1": "value1",
  "key2": "value2"
}''')).called(1);
  });

  test('create directory', () async {
    final settings = JSettings('watched.json');

    final dir = MockDirectory('.');
    when(dir.existsSync()).thenReturn(false);
    when(dir.watch()).thenAnswer((_) => const Stream<FileSystemEvent>.empty());

    await IOOverrides.runZoned(() async {
      await settings.init();
    }, createDirectory: (path) {
      expect(path, dir.path);
      return dir;
    });

    verify(dir.existsSync()).called(isPositive);
    verify(dir.createSync(recursive: true)).called(1);
  });

  test('watch changes', () async {
    final settings = JSettings('/path/to/watched.json');

    final events = StreamController<FileSystemEvent>();

    final dir = MockDirectory('/path/to');
    when(dir.existsSync()).thenReturn(true);
    when(dir.watch()).thenAnswer((_) => events.stream);

    final file = MockFile('/path/to/watched.json');
    when(file.existsSync()).thenReturn(true);
    when(file.lastModifiedSync()).thenReturn(unixTime(0));
    when(file.readAsStringSync()).thenReturn('{"key":"value"}');

    await IOOverrides.runZoned(() async {
      await settings.init();
    }, createDirectory: (path) {
      expect(path, dir.path);
      return dir;
    }, createFile: (path) {
      expect(path, file.path);
      return file;
    });
    expect(events.hasListener, isTrue);

    verify(dir.existsSync()).called(isPositive);
    verifyNever(dir.createSync(recursive: true));
    verify(dir.watch()).called(1);

    events.add(FakeFileSystemEvent.create('/path/to/watched.json'));
    await expectLater(settings.added, emits('key'));

    when(file.lastModifiedSync()).thenReturn(unixTime(1));
    when(file.readAsStringSync()).thenReturn('{"key":"changed"}');

    events.add(FakeFileSystemEvent.modify('/path/to/watched.json'));
    await expectLater(settings.changed, emits('key'));

    when(file.existsSync()).thenReturn(false);

    events.add(FakeFileSystemEvent.delete('/path/to/watched.json'));
    await expectLater(settings.removed, emits('key'));

    await settings.close();
    expect(events.hasListener, isFalse);
  });

  test('emit explicit changes', () async {
    final settings = JSettings('settings.json');

    final file = MockFile('settings.json');
    when(file.existsSync()).thenReturn(true);
    when(file.lastModifiedSync()).thenReturn(unixTime(0));
    when(file.readAsStringSync()).thenReturn('');
    when(file.writeAsString(any)).thenAnswer((_) async => file);

    await IOOverrides.runZoned(() async {
      expect(settings.added, emits('foo'));
      await settings.setValue('foo', 'bar');

      expect(settings.changed, emits('foo'));
      await settings.setValue('foo', 'baz');

      expect(settings.removed, emits('foo'));
      await settings.setValue('foo', null);
    }, createFile: (path) {
      expect(path, file.path);
      return file;
    });
  });
}
