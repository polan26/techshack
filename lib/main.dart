import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv package
import 'qr_scanner.dart'; // Import your QrScanner widget
import 'serial_number_model.dart'; // Import your SerialNumberModel
import 'sales_data.dart'; // Import your SalesData model
import 'firebase_options.dart'; // Import the generated Firebase options

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file
  await dotenv.load(fileName: ".env");

  // Initialize Firebase with options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // ignore: avoid_print
    print("Firebase initialized successfully");
  } catch (e) {
    // ignore: avoid_print
    print("Error initializing Firebase: $e");
  }

  // Initialize MultiProvider
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => SerialNumberModel(),
        ),
        ChangeNotifierProvider(
          create: (context) => SalesData(), // Add SalesData here
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TechShack',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home:
          const QrScanner(), // Make sure QrScanner is within the provider's scope
    );
  }
}
