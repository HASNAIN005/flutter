import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'edit_card_screen.dart';
import 'package:http/http.dart' as http;

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pickImage();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final croppedFile = await _cropImage(File(pickedFile.path));

      if (croppedFile != null) {
        setState(() {
          _isLoading = true; // Show loading indicator while processing
        });

        // Unique cardId generation
        final cardId = _generateUniqueCardId();

        // Upload image to Firebase Storage
        final uploadUrl = await _uploadToFirebase(croppedFile, cardId);

        if (uploadUrl.isNotEmpty) {
          print('Uploaded file URL: $uploadUrl');

          // Perform OCR and send to the backend
          await _performOCRAndSendToBackend(croppedFile.path, cardId, uploadUrl);
        }
      } else {
        if (mounted) {
          Navigator.pop(context); // Close the screen if no image was cropped
        }
      }
    } else {
      if (mounted) {
        Navigator.pop(context); // Close the screen if no image was selected
      }
    }
  }

  Future<File?> _cropImage(File image) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cropper',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    } else {
      return null;
    }
  }

  String _generateUniqueCardId() {
    return FirebaseFirestore.instance.collection('cards').doc().id; // Generate a unique cardId
  }

  Future<String> _uploadToFirebase(File image, String cardId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child('images/$cardId.jpg');
      final uploadTask = imageRef.putFile(image);

      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Image successfully uploaded to Firebase Storage. URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      return '';
    }
  }

  Future<void> _performOCRAndSendToBackend(String imagePath, String cardId, String imageUrl) async {
    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);

      final rawText = recognizedText.text;
      print('Raw OCR Text: $rawText');

      // Extract bounding boxes for each line
      final textLines = recognizedText.blocks.expand((block) => block.lines).toList();

      // Send raw text to backend
      final response = await _sendRawTextToBackend(rawText);

      if (response != null) {
        // Navigate to the edit screen with the data
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ViewEditSaveScreen(
                imagePath: imagePath,
                extractedData: response,
                onSave: (_) {}, // Database insertion happens in ViewEditSaveScreen
                textLines: textLines,
                cardId: cardId,
                imageUrl: imageUrl,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false; // Hide loading indicator if backend call fails
        });
      }
    } catch (e) {
      print('Error during OCR or backend communication: $e');
      setState(() {
        _isLoading = false; // Hide loading indicator if an error occurs
      });
    } finally {
      textRecognizer.close();
    }
  }

  Future<Map<String, dynamic>?> _sendRawTextToBackend(String rawText) async {
    const backendUrl = 'https://scanxpertimg-979948311492.europe-west4.run.app/extract';
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': rawText}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to communicate with backend. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error sending raw text to backend: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator() // Show loading indicator if loading
            : const Text('Processing selected image...'),
      ),
    );
  }
}