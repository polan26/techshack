import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  _InventoryState createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  final List<InventoryItem> items = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
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

  // Load inventory for the selected branch
  Future<void> _loadInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? inventoryJson = prefs.getString(
        'inventory_branch_$selectedBranch'); // Load specific branch inventory

    if (inventoryJson != null) {
      final List<dynamic> decodedList = jsonDecode(inventoryJson);
      setState(() {
        items.clear(); // Clear the list before loading new items
        items.addAll(
          decodedList.map((item) => InventoryItem.fromJson(item)).toList(),
        );
      });
    } else {
      setState(() {
        items.clear(); // Clear the list if no inventory is found for the branch
      });
    }
  }

  Future<void> _saveInventory() async {
    final prefs = await SharedPreferences.getInstance();
    final String inventoryJson =
        jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString('inventory_branch_$selectedBranch',
        inventoryJson); // Save for the specific branch
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

  void _deleteItem(int index) {
    setState(() {
      String itemName = items[index].name;
      items.removeAt(index);
      _saveInventory();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('$itemName removed from Branch $selectedBranch inventory')));
    });
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
                      return ListTile(
                        title: Text(items[index].name),
                        subtitle: Text('Quantity: ${items[index].quantity}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => _decreaseQuantity(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _increaseQuantity(index),
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
