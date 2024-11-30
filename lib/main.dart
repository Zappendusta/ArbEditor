import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io' as io;

void main() {
  runApp(const ArbEditor());
}

class ArbEditor extends StatelessWidget {
  const ArbEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'ARB Editor', home: Scaffold(body: NewWidget()));
  }
}

class NewWidget extends StatefulWidget {
  const NewWidget({
    super.key,
  });

  @override
  State<NewWidget> createState() => _NewWidgetState();
}

class _NewWidgetState extends State<NewWidget> {
  var folder = '';
  var arbFiles = <ArbFile>[];
  List<String> get locales => arbFiles.map((e) => e.locale).toList();
  List<String> get distinctKeys =>
      arbFiles.expand((e) => e.entries.keys).toSet().toList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () async {
                  var selectedDirectory =
                      await FilePicker.platform.getDirectoryPath();

                  if (selectedDirectory == null) {
                    return;
                  }

                  setState(() {
                    folder = selectedDirectory;
                  });
                },
                child: Text('Pick Folder'),
              ),
              ElevatedButton(
                onPressed: folder.isEmpty ? null : analyze,
                child: Text('Analyze again'),
              ),
              ElevatedButton(
                onPressed: folder.isEmpty ? null : saveAll,
                child: Text('Save all'),
              ),
            ],
          ),
          Text(folder),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(),
                children: [
                  TableRow(
                    children: [
                      Text('locale'),
                      for (var locale in locales) Text(locale),
                    ],
                  ),
                  ...distinctKeys.map(
                    (key) => TableRow(
                      children: [
                        TableCell(
                          child: Column(
                            children: [
                              Text(key),
                              Text(
                                arbFiles
                                        .firstWhere(
                                          (e) =>
                                              e.entries[key]?.description !=
                                                  '' &&
                                              e.entries[key]?.description !=
                                                  null,
                                          orElse: () => ArbFile(''),
                                        )
                                        .entries[key]
                                        ?.description
                                        .toString() ??
                                    '',
                              ),
                            ],
                          ),
                        ),
                        for (var locale in locales)
                          TableCell(
                            child: Builder(
                              builder: (context) {
                                var value = arbFiles
                                    .firstWhere((e) => e.locale == locale)
                                    .entries[key]
                                    ?.value;

                                return EditingCellTextField(
                                  value: value,
                                  onChanged: (p0) {
                                    arbFiles
                                        .firstWhere((e) => e.locale == locale)
                                        .entries[key]!
                                        .value = p0;
                                    setState(() {
                                      arbFiles = arbFiles;
                                    });
                                    debouncedSave();
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  var saving = false;
  void debouncedSave() async {
    if (saving) return;
    saving = true;
    await Future.delayed(Duration(seconds: 2));
    saveAll();
    print('saved');
    saving = false;
  }

  Future analyze() async {
    if (folder.isEmpty) return;

    var folderFiles = io.Directory(folder).listSync();

    arbFiles.clear();

    for (var file in folderFiles) {
      if (file.path.endsWith('.arb')) {
        var arbFile = ArbFile(file.path);
        await arbFile.analyze();
        arbFiles.add(arbFile);
      }
    }

    setState(() {
      arbFiles = arbFiles;
    });
  }

  Future saveAll() async {
    for (var arbFile in arbFiles) {
      await arbFile.saveBackToFile();
    }
  }
}

class ArbFile {
  final String path;
  var content = '';
  var locale = '';
  var entries = <String, ArbEntry>{};

  ArbFile(this.path);

  Future analyze() async {
    content = await io.File(path).readAsString();

    var raw = jsonDecode(content) as Map<String, dynamic>;

    for (var rawEntry in raw.entries) {
      var key = rawEntry.key;
      var value = rawEntry.value;

      if (key == '@@locale') {
        locale = value;
        continue;
      }

      if (key.startsWith('@@')) {
        continue;
      }

      if (key.startsWith('@')) {
        key = key.substring(1);
        entries.containsKey(key)
            ? entries[key]!.description = value
            : entries[key] = ArbEntry(key, '', value);
        continue;
      }

      entries.containsKey(key)
          ? entries[key]!.value = value
          : entries[key] = ArbEntry(key, value, '');
    }
  }

  Future saveBackToFile() async {
    var raw = <String, dynamic>{};

    if (locale.isNotEmpty) raw['@@locale'] = locale;

    for (var entry in entries.entries) {
      var key = entry.key;
      var value = entry.value.value;
      var description = entry.value.description;

      raw[key] = value;

      if (description != null && description != '') {
        raw['@$key'] = description;
      }
    }

    var qqq = JsonEncoder.withIndent('    ').convert(raw);
    await io.File(path).writeAsString(qqq);
  }
}

class ArbEntry {
  final String key;
  var value = '';
  dynamic description = '';

  ArbEntry(this.key, this.value, this.description);
}

class EditingCellTextField extends StatefulWidget {
  const EditingCellTextField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final void Function(String) onChanged;

  @override
  State<EditingCellTextField> createState() => _EditingCellTextFieldState();
}

class _EditingCellTextFieldState extends State<EditingCellTextField> {
  var isEditing = false;
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.text = widget.value ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (event) {
        setState(() => isEditing = false);
        if (controller.text != widget.value) {
          widget.onChanged(controller.text);
        }
      },
      onTapInside: (event) {
        setState(() => isEditing = true);
      },
      child: isEditing
          ? TextField(
              autofocus: true,
              controller: controller,
              onSubmitted: (value) {
                widget.onChanged(value);
                setState(() => isEditing = false);
              },
            )
          : TextButton(
              onPressed: () => setState(() => isEditing = true),
              child: Text(widget.value ?? ''),
            ),
    );
  }
}
