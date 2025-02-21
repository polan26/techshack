import 'package:flutter/material.dart';

class UserGuide extends StatelessWidget {
  const UserGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          GuideItem(
            imagePath: 'assets/flash.png',
            description: 'Switch for on/off for flashlight',
          ),
          GuideItem(
            imagePath: 'assets/camera.png',
            description: 'Switch camera to front and back',
          ),
          GuideItem(
              imagePath: 'assets/select_category.png',
              description: 'select category where you want to save'),
          GuideItem(
            imagePath: 'assets/app_drawer.png',
            description: 'Open menu icon',
          ),
          GuideItem(
              imagePath: 'assets/SN.png',
              description: 'Check Serial Number History'),
          GuideItem(
              imagePath: 'assets/inventory.png',
              description: 'View and edit inventory'),
          GuideItem(
              imagePath: 'assets/admin_login.png',
              description: 'login as admin to edit inventory'),
          GuideItem(
              imagePath: 'assets/admin.png',
              description: 'enter email and password if you are a admin'),
          GuideItem(
              imagePath: 'assets/edit_inventory.png',
              description: 'You can now edit and add products'),
          GuideItem(
              imagePath: 'assets/daily_sales.png',
              description: 'navigate to daily sales'),
          GuideItem(
              imagePath: 'assets/add_product_sales.png',
              description: 'you can add a product that has been sold that day'),
          GuideItem(
              imagePath: 'assets/enter_product.png',
              description:
                  'enter product name and price, you can also delete the product you have added or edit it'),
          GuideItem(
              imagePath: 'assets/weekly_summary.png',
              description: 'View weekly_summary'),
          GuideItem(
              imagePath: 'assets/weekly_summary_total.png',
              description:
                  'Here you can see all the products that have been this week'),
        ],
      ),
    );
  }
}

class GuideItem extends StatelessWidget {
  final String imagePath;
  final String description;

  const GuideItem({
    super.key,
    required this.imagePath,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(imagePath),
        const SizedBox(height: 8.0),
        Text(
          description,
          style: const TextStyle(fontSize: 20.0),
        ),
        const SizedBox(height: 14.0),
      ],
    );
  }
}
