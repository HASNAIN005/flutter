import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TextScreen extends StatefulWidget {
  const TextScreen({Key? key}) : super(key: key);

  @override
  State<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends State<TextScreen> {
  late List<File> _textFiles;

  @override
  void initState() {
    super.initState();
    _loadTextFiles();
  }

  Future<void> _loadTextFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final detailsDir = Directory('${directory.path}/ID_DETAILS');
    if (await detailsDir.exists()) {
      setState(() {
        _textFiles = detailsDir.listSync().whereType<File>().toList();
      });
    } else {
      setState(() {
        _textFiles = [];
      });
    }
  }

  Future<void> _deleteFile(File file) async {
    await file.delete();
    _loadTextFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Details'),
      ),
      body: _textFiles.isEmpty
          ? const Center(child: Text('No ID Details Found'))
          : ListView.builder(
              itemCount: _textFiles.length,
              itemBuilder: (context, index) {
                final file = _textFiles[index];
                return ListTile(
                  title: Text(file.path.split('/').last),
                  onTap: () async {
                    final text = await file.readAsString();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('ID Details'),
                        content: Text(text),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteFile(file),
                  ),
                );
              },
            ),
    );
  }
}
