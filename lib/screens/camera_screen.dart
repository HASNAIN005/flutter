import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'edit_card_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final DocumentScannerOptions documentOptions = DocumentScannerOptions(
    documentFormat: DocumentFormat.jpeg,
    mode: ScannerMode.filter,
    pageLimit: 1,
  );

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDocumentScanning();
  }

  Future<void> _startDocumentScanning() async {
    final documentScanner = DocumentScanner(options: documentOptions);
    try {
      final DocumentScanningResult result = await documentScanner.scanDocument();
      if (result.images.isNotEmpty) {
        final scannedImage = File(result.images.first);
        final savedImagePath = await _saveImage(scannedImage);

        setState(() {
          _isLoading = true; // Show loading indicator while processing
        });

        // Unique cardId generation
        final cardId = _generateUniqueCardId();

        // Upload image to Firebase Storage
        final uploadUrl = await _uploadToFirebase(scannedImage, cardId);

        if (uploadUrl.isNotEmpty) {
          print('Uploaded file URL: $uploadUrl');

          // Perform OCR and send to the backend
          await _performOCRAndSendToBackend(savedImagePath, cardId, uploadUrl);
        }
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error during document scanning: $e');
      Navigator.pop(context);
    } finally {
      documentScanner.close();
    }
  }

  Future<String> _saveImage(File image) async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${directory.path}/ID_IMAGES');
    if (!(await imageDir.exists())) {
      await imageDir.create();
    }
    final savedImagePath = '${imageDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await image.copy(savedImagePath);
    return savedImagePath;
  }

  String _generateUniqueCardId() {
    return FirebaseFirestore.instance.collection('cards').doc().id; // Generate a unique cardId
  }

  Future<String> _uploadToFirebase(File image, String cardId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child('images/$cardId.jpg'); // Use cardId as the file name
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
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator() // Show loading indicator if loading
            : const Text('Processing scanned document...'),
      ),
    );
  }
}