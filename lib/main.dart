import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'qr_scanner.dart'; // Import your QrScanner widget
import 'serial_number_model.dart'; // Import your SerialNumberModel

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => SerialNumberModel(),
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
      home: const QrScanner(),
    );
  }
}
