import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'database_helper.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({Key? key}) : super(key: key);

  @override
  _DataScreenState createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _cards = [];
  String _filterColumn = 'Name';
  String _filterValue = '';
  int _currentPage = 1;
  final int _pageSize = 10;
  int _totalPages = 1;
  bool _isLoading = true; // Loading state
  Map<String, String> _imageUrls = {}; // Map to store image URLs from Firebase Storage

  @override
  void initState() {
    super.initState();
    _fetchData(); // Fetch data and images during initialization
    _printAllCards(); // Print all records
  }

  Future<void> _fetchData({int page = 1}) async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // Get the current user's email
      final userEmail = _auth.currentUser?.email;

      if (userEmail == null) {
        print('User is not signed in.');
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
        return;
      }

      // Query the 'cards' sub-collection under the 'users' document
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('cards') // Access the 'cards' sub-collection
          .get();

      // Map the fetched documents to a list of card data
      final fetchedCards = querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      // Fetch the corresponding images from Firebase Storage for these cards
      await _fetchImagesFromFirebaseStorage(fetchedCards);

      setState(() {
        _cards = fetchedCards; // Update the state with the fetched card data
        _currentPage = page;
        _totalPages = (_cards.length / _pageSize).ceil();
        _isLoading = false; // Hide loading indicator
      });
    } catch (e) {
      print('Error fetching cards: $e');
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  Future<void> _printAllCards() async {
    print("Printing all cards...");
    final cards = await _dbHelper.getAllCards(); // Assuming _dbHelper.getAllCards() fetches all cards.
    print("All Cards: $cards");
  }

  Future<void> _fetchImagesFromFirebaseStorage(List<Map<String, dynamic>> cards) async {
    try {
      Map<String, String> fetchedUrls = {};
      for (var card in cards) {
        final cardId = card['cardId']; // Use 'cardId' to fetch image
        if (cardId != null) {
          try {
            final ref = FirebaseStorage.instance.ref().child('images/$cardId.jpg');
            final url = await ref.getDownloadURL(); // Get the download URL for the image
            fetchedUrls[cardId] = url;
          } catch (e) {
            print("Error fetching image for cardId $cardId: $e");
          }
        }
      }

      // Update the state with the fetched image URLs
      setState(() {
        _imageUrls = fetchedUrls;
      });
    } catch (e) {
      print('Error fetching images from Firebase Storage: $e');
    }
  }

  Future<void> _deleteCard(String cardId) async {
    try {
      final userEmail = _auth.currentUser?.email;

      if (userEmail == null) {
        print('User is not signed in.');
        return;
      }

      // Delete the card document from Firestore
      await _firestore.collection('users').doc(userEmail).collection('cards').doc(cardId).delete();

      // Delete the associated image from Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('images/$cardId.jpg');
      await ref.delete();

      // Remove the card locally
      setState(() {
        _cards.removeWhere((card) => card['cardId'] == cardId);
        _imageUrls.remove(cardId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card deleted successfully')),
      );
    } catch (e) {
      print('Error deleting card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete card')),
      );
    }
  }

  Future<void> _showDeleteConfirmation(String cardId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Confirmation'),
          content: const Text('Are you sure you want to delete this card?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                await _deleteCard(cardId); // Proceed with deletion
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyFilter() async {
    if (_filterColumn.isEmpty || _filterValue.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final filteredCards = _cards.where((card) {
      final value = card[_filterColumn]?.toString().toLowerCase() ?? '';
      return value.contains(_filterValue.toLowerCase());
    }).toList();

    setState(() {
      _cards = filteredCards;
      _totalPages = 1; // No pagination for filtered results
      _isLoading = false;
    });
  }

  void _showPreview(String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Image.network(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Data',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchData(page: 1);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Filter Row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterColumn,
                          decoration: const InputDecoration(
                            labelText: 'Filter By',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Name', child: Text('Name')),
                            DropdownMenuItem(value: 'Address', child: Text('Address')),
                            DropdownMenuItem(value: 'company_name', child: Text('Company')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filterColumn = value ?? 'Name';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Filter Value',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          onChanged: (value) {
                            _filterValue = value;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.blueAccent),
                        onPressed: _applyFilter,
                      ),
                    ],
                  ),
                  // Data List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cards.length,
                      itemBuilder: (context, index) {
                        final card = _cards[index];
                        final cardId = card['cardId'];
                        final imagePath = _imageUrls[cardId];

                        return Card(
                          margin: const EdgeInsets.all(8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image Preview
                                    if (imagePath != null)
                                      GestureDetector(
                                        onTap: () => _showPreview(imagePath),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imagePath,
                                            height: 50,
                                            width: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(Icons.broken_image,
                                                  size: 50, color: Colors.grey);
                                            },
                                          ),
                                        ),
                                      )
                                    else
                                      Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                    const SizedBox(width: 10),
                                    // Card Information
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Name: ${card['Name'] ?? 'N/A'}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Designation: ${card['Designation'] ?? 'N/A'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Company Name: ${card['company_name'] ?? 'N/A'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Cell: ${card['Cell'] ?? 'N/A'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Email: ${card['Email'] ?? 'N/A'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Fax: ${card['Fax'] ?? 'N/A'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Tel: ${card['Tel'] ?? 'N/A'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Website: ${card['Website'] ?? 'N/A'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Address: ${card['Address'] ?? 'N/A'}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Delete Icon with Confirmation
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        await _showDeleteConfirmation(cardId);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}