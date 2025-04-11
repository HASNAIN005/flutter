import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'database_helper.dart';

class ViewEditSaveScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic>? extractedData;
  final void Function(Map<String, dynamic>) onSave;
  final List<TextLine> textLines;
  final String cardId;
  final String imageUrl;

  const ViewEditSaveScreen({
    Key? key,
    required this.imagePath,
    required this.extractedData,
    required this.onSave,
    required this.textLines,
    required this.cardId,
    required this.imageUrl,
  }) : super(key: key);

  @override
  _ViewEditSaveScreenState createState() => _ViewEditSaveScreenState();
}

class _ViewEditSaveScreenState extends State<ViewEditSaveScreen> {
  late File _image;
  late ui.Image _uiImage;
  Map<String, TextEditingController> _controllers = {};
  bool _isImageLoaded = false;
  bool _isDataSaved = false; // To prevent multiple saves

  @override
  void initState() {
    super.initState();
    _image = File(widget.imagePath);
    _initializeFields();
    _loadImage();
  }

  void _initializeFields() {
    _controllers = {
      'Name': TextEditingController(),
      'Designation': TextEditingController(),
      'company_name': TextEditingController(),
      'Cell': TextEditingController(),
      'Tel': TextEditingController(),
      'Fax': TextEditingController(),
      'Email': TextEditingController(),
      'Address': TextEditingController(),
      'Website': TextEditingController(),
    };

    if (widget.extractedData != null) {
      widget.extractedData!.forEach((key, value) {
        if (_controllers.containsKey(key)) {
          _controllers[key]!.text = value;
        }
      });
    }
  }

  Future<void> _loadImage() async {
    final data = await _image.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    setState(() {
      _uiImage = frame.image;
      _isImageLoaded = true;
      print('Image loaded with dimensions: ${_uiImage.width} x ${_uiImage.height}');
    });
  }

  void _assignTextToField(String text) async {
    print('Selected text: $text');
    final field = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Assign Text to Field"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _controllers.keys
                .map((field) => ListTile(
                      title: Text(field),
                      onTap: () {
                        print('Selected field: $field');
                        Navigator.of(context).pop(field);
                      },
                    ))
                .toList(),
          ),
        );
      },
    );

    if (field != null) {
      setState(() {
        _controllers[field]!.text = text;
        print('Updated field: $field with text: $text');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Your Info'),
      ),
      body: Column(
        children: [
          // Display the snapped or selected image
          if (_isImageLoaded)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(_image),
                  fit: BoxFit.contain,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final displayWidth = constraints.maxWidth;
                  final displayHeight = displayWidth * (_uiImage.height / _uiImage.width);

                  return Stack(
                    children: [
                      Image.file(
                        _image,
                        width: displayWidth,
                        height: displayHeight,
                        fit: BoxFit.contain,
                      ),
                      ...widget.textLines.map((line) {
                        final rect = Rect.fromLTRB(
                          line.boundingBox.left * (displayWidth / _uiImage.width),
                          line.boundingBox.top * (displayHeight / _uiImage.height),
                          line.boundingBox.right * (displayWidth / _uiImage.width),
                          line.boundingBox.bottom * (displayHeight / _uiImage.height),
                        );

                        return Positioned(
                          left: rect.left,
                          top: rect.top,
                          width: rect.width,
                          height: rect.height,
                          child: GestureDetector(
                            onTap: () {
                              print('Tapped on text: ${line.text}');
                              _assignTextToField(line.text);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red, width: 2),
                                color: Colors.red.withOpacity(0.2),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          // Form for editing extracted data
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _controllers.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextFormField(
                          controller: entry.value,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          // Save button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                if (_isDataSaved) return; // Prevent multiple saves
                setState(() {
                  _isDataSaved = true; // Mark data as saved
                });

                final updatedFields = _controllers.map((key, value) => MapEntry(key, value.text));
                updatedFields['cardId'] = widget.cardId; // Use the passed cardId
                updatedFields['imageUrl'] = widget.imageUrl; // Use the passed imageUrl
                print('Fields to save: $updatedFields');

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.email)
                    .collection('cards')
                    .doc(widget.cardId)
                    .set(updatedFields);

                widget.onSave(updatedFields);
                Navigator.pop(context);
              },
              child: const Text('Save Data'),
            ),
          ),
        ],
      ),
    );
  }
}