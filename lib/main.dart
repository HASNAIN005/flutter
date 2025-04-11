import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/view_images_screen.dart';
import 'screens/data_screen.dart';
import 'screens/gallery_screen.dart'; // Import the GalleryScreen
import 'screens/Signup_Login/welcome_screen.dart'; // Import the WelcomeScreen

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove the debug banner
      title: 'ID Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WelcomeScreen(), // Set WelcomeScreen as the home screen
      routes: {
        '/camera': (context) => CameraScreen(),
        '/view_images': (context) => const ViewImagesScreen(),
        '/data_screen': (context) => const DataScreen(),
        '/gallery': (context) => const GalleryScreen(), 
      },
    );
  }
}