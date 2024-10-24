import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
// Import Firebase Core
import 'package:permission_handler/permission_handler.dart';

class InventoryItem {
  String name;
  int quantity;

  InventoryItem({required this.name, this.quantity = 0});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
    };
  }

  static InventoryItem fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name'],
      quantity: json['quantity'],
    );
  }
}

class Inventory extends StatefulWidget {
  const Inventory({super.key});

  @override
  InventoryState createState() => InventoryState();
}

class InventoryState extends State<Inventory> {
  final List<InventoryItem> items = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore firestore =
      FirebaseFirestore.instance; // Firestore instance
  int selectedBranch = 1; // Default to Branch 1

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadInventory();
  }

  // Initialize notifications
  Future<void> _initializeNotifications() async {
    if (await Permission.notification.request().isGranted) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/notification');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'stock_channel', // The id of the channel.
        'Stock Notifications', // The human-readable name of the channel.
        description: 'Notification for low stock items',
        importance: Importance.high, // Set importance to high
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // Load inventory for the selected branch from Firestore
  Future<void> _loadInventory() async {
    final QuerySnapshot snapshot = await firestore
        .collection('inventory')
        .doc('branch_$selectedBranch')
        .collection('items')
        .get();

    setState(() {
      items.clear(); // Clear the list before loading new items
      items.addAll(
        snapshot.docs
            .map((doc) =>
                InventoryItem.fromJson(doc.data() as Map<String, dynamic>))
            .toList(),
      );
    });
  }

  // Save inventory to Firestore
  Future<void> _saveInventory() async {
    for (InventoryItem item in items) {
      await firestore
          .collection('inventory')
          .doc('branch_$selectedBranch')
          .collection('items')
          .doc(item
              .name) // Use item name as the document ID or generate a unique ID
          .set(item.toJson());
    }
  }

  void _addItem(String name) {
    setState(() {
      items.add(InventoryItem(name: name));
    });
    _saveInventory();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name added to Branch $selectedBranch inventory')));
  }

  void _increaseQuantity(int index) {
    setState(() {
      items[index].quantity++;
    });
    _saveInventory();
  }

  void _decreaseQuantity(int index) {
    setState(() {
      if (items[index].quantity > 0) {
        items[index].quantity--;
      }
    });
    _saveInventory();
    _checkStockLevel(index);
  }

  void _checkStockLevel(int index) {
    if (items[index].quantity < 5) {
      _showNotification(items[index]);
    }
  }

  Future<void> _showNotification(InventoryItem item) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'stock_channel', // Channel ID
      'Stock Notifications', // Channel Name
      channelDescription: 'Notification for low stock items',
      importance: Importance.high, // High importance
      priority: Priority.high,
      showWhen: true, // Show timestamp
      playSound: true, // Play sound
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Low Stock Alert', // Notification title
      '${item.name} stock is low: ${item.quantity} left!', // Notification body
      platformChannelSpecifics,
      payload: 'item_${item.name}', // Optional payload for additional data
    );
  }

  void _deleteItem(int index) async {
    String itemName = items[index].name; // Store item name for notification

    // Remove the item from local state
    setState(() {
      items.removeAt(index);
    });

    // Delete from Firestore
    try {
      await firestore
          .collection('inventory')
          .doc('branch_$selectedBranch')
          .collection('items')
          .doc(itemName) // Use the item name or unique ID
          .delete();

      // Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$itemName removed from Branch $selectedBranch inventory')));
      }
    } catch (e) {
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing $itemName: $e')));
      }
    }
  }

  // Function to switch branches
  void _switchBranch(int branch) {
    setState(() {
      selectedBranch = branch;
      items
          .clear(); // Clear current list to avoid showing the previous branch's items
      _loadInventory(); // Load inventory for the selected branch
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Branch $selectedBranch Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              TextEditingController controller = TextEditingController();
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Add Item'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: 'Item name'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            _addItem(controller.text);
                          }
                          Navigator.of(context).pop();
                        },
                        child: const Text('Add'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Branch selection buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _switchBranch(1),
                  child: const Text('Branch 1'),
                ),
                ElevatedButton(
                  onPressed: () => _switchBranch(2),
                  child: const Text('Branch 2'),
                ),
                ElevatedButton(
                  onPressed: () => _switchBranch(3),
                  child: const Text('Branch 3'),
                ),
                ElevatedButton(
                  onPressed: () => _switchBranch(4),
                  child: const Text('Branch 4'),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No items in inventory.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text('Quantity: ${item.quantity}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _increaseQuantity(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => _decreaseQuantity(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteItem(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
