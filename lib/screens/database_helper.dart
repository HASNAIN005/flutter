import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DatabaseHelper._internal();

  String get _userEmail {
    final user = _auth.currentUser;
    if (user != null) {
      return user.email!;
    }
    throw Exception('User not logged in');
  }

  // -------------------- Cards Collection Methods --------------------
  Future<void> insertCard(Map<String, dynamic> card) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userEmail)
          .collection('cards')
          .add(card);
    } catch (e) {
      print('Error inserting card: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllCards() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userEmail)
          .collection('cards')
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching cards: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCardsByPage(int page, int pageSize) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userEmail)
          .collection('cards')
          .orderBy('Name', descending: true) // Order by a valid field, e.g., 'Name'
          .limit(pageSize)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching paginated cards: $e');
      return [];
    }
  }

  Future<int> getTotalCardCount() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userEmail)
          .collection('cards')
          .get();

      return snapshot.size;
    } catch (e) {
      print('Error fetching total card count: $e');
      return 0;
    }
  }

  Future<void> deleteCard(String id) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userEmail)
          .collection('cards')
          .doc(id)
          .delete();
    } catch (e) {
      print('Error deleting card: $e');
    }
  }

  Future<List<Map<String, dynamic>>> filterCards(String column, String value,
      {bool partialMatch = false}) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(_userEmail)
          .collection('cards');

      if (partialMatch) {
        query = query.where(column, isGreaterThanOrEqualTo: value);
      } else {
        query = query.where(column, isEqualTo: value);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error filtering cards: $e');
      return [];
    }
  }

  // -------------------- Images Collection Methods --------------------
  Future<void> insertImage(Map<String, dynamic> image) async {
    try {
      print('Attempting to insert image metadata: $image');
      await _firestore.collection('images').add(image);
      print('Image metadata successfully inserted into Firestore.');
    } catch (e) {
      print('Error inserting image: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getImagesByUser() async {
    try {
      final snapshot = await _firestore
          .collection('images')
          .where('email', isEqualTo: _userEmail)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching images: $e');
      return [];
    }
  }

  Future<void> deleteImage(String id) async {
    try {
      await _firestore.collection('images').doc(id).delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }
}