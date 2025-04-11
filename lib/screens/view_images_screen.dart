import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ViewImagesScreen extends StatefulWidget {
  const ViewImagesScreen({Key? key}) : super(key: key);

  @override
  _ViewImagesScreenState createState() => _ViewImagesScreenState();
}

class _ViewImagesScreenState extends State<ViewImagesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _images = [];
  bool _isLoading = true; // Track if images are being loaded

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      final userEmail = _auth.currentUser?.email;

      if (userEmail == null) {
        print('No user is signed in.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Listen to Firestore updates in real-time
      _firestore
          .collection('users')
          .doc(userEmail)
          .collection('cards')
          .snapshots()
          .listen((querySnapshot) async {
        final List<Map<String, dynamic>> fetchedImages = [];

        for (var doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final cardId = data['cardId'];

          if (cardId != null) {
            // Construct Firebase Storage path
            final imagePath = 'images/$cardId.jpg';

            try {
              // Fetch the download URL for the image
              final downloadUrl = await FirebaseStorage.instance.ref(imagePath).getDownloadURL();

              fetchedImages.add({
                'id': doc.id,
                'filePath': downloadUrl,
                ...data,
              });
            } catch (e) {
              print('Error fetching image for cardId $cardId: $e');
            }
          }
        }

        setState(() {
          _images = fetchedImages; // Update the state with fetched images
          _isLoading = false; // Hide loading indicator
        });
      }, onError: (error) {
        print('Error listening to Firestore changes: $error');
        setState(() {
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error fetching images: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteImage(String docId, String filePath) async {
    try {
      // Delete the image from Firebase Storage
      final storageRef = FirebaseStorage.instance.refFromURL(filePath);
      await storageRef.delete();

      // Delete the image metadata from Firestore
      final userEmail = _auth.currentUser?.email;
      if (userEmail != null) {
        await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('cards')
            .doc(docId)
            .delete();
      }

      // Remove the image from the local state
      setState(() {
        _images = _images.where((image) => image['id'] != docId).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image deleted successfully')),
      );
    } catch (e) {
      print('Error deleting image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete image')),
      );
    }
  }

  void _confirmDelete(String docId, String filePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _deleteImage(docId, filePath); // Delete the image
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showImagePreview(String imagePath, String docId) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image Preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Save Button
                    ElevatedButton(
                      onPressed: () async {
                        await _saveToGallery(imagePath);
                        Navigator.pop(context); // Close the dialog after saving
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.blue,
                        shadowColor: Colors.blueAccent,
                        elevation: 8,
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.save, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Save to Gallery', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    // Delete Button
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close the dialog
                        _confirmDelete(docId, imagePath); // Show delete confirmation dialog
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.red,
                        shadowColor: Colors.redAccent,
                        elevation: 8,
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.delete, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Back Button Positioned Top-Right
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, size: 24, color: Colors.white),
                onPressed: () => Navigator.pop(context), // Close the dialog
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery(String imagePath) async {
    try {
      await GallerySaver.saveImage(imagePath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to gallery')),
      );
    } catch (e) {
      print('Error saving image to gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save image to gallery')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Uploaded Images'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(), // Display loading indicator
            )
          : _images.isEmpty
              ? const Center(
                  child: Text(
                    'No images found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Two images per row
                      crossAxisSpacing: 16.0, // Add space between images horizontally
                      mainAxisSpacing: 16.0, // Add space between images vertically
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final image = _images[index];
                      final filePath = image['filePath'];
                      final docId = image['id'];

                      return GestureDetector(
                        onTap: () => _showImagePreview(filePath, docId), // Show preview on tap
                        child: Material(
                          elevation: 4, // Add shadow for depth
                          borderRadius: BorderRadius.circular(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                // Display the image
                                Positioned.fill(
                                  child: Image.network(
                                    filePath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
                                    },
                                  ),
                                ),
                                // Gradient Overlay
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.6),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}