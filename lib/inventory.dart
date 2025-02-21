import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'admin_login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late SharedPreferences _prefs;
  final List<InventoryItem> items = [];
  final List<InventoryItem> filteredItems = []; // For search functionality
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  int selectedBranch = 1;
  bool isLoading = false; // Track the loading state
  bool isAdminLoggedIn = false; // Track if admin is logged in
  final TextEditingController _searchController =
      TextEditingController(); // Search controller
  final Map<String, TextEditingController> _quantityControllers =
      {}; // Controllers for quantity input

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeNotifications();
    _loadInventory();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    bool isAdmin = _prefs.getBool('isAdminLoggedIn') ?? false;

    setState(() {
      isAdminLoggedIn = isAdmin;
    });
  }

  void _updateLoginStatus(bool isAdmin) {
    setState(() {
      isAdminLoggedIn = isAdmin;
    });
    _prefs.setBool('isAdminLoggedIn', isAdmin);
  }

  Future<void> _initializeNotifications() async {
    if (await Permission.notification.request().isGranted) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/notification');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'stock_channel',
        'Stock Notifications',
        description: 'Notification for low stock items',
        importance: Importance.high,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _loadInventory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final QuerySnapshot snapshot = await firestore
          .collection('inventory')
          .doc('branch_$selectedBranch')
          .collection('items')
          .get();

      setState(() {
        items.clear();
        items.addAll(
          snapshot.docs
              .map((doc) =>
                  InventoryItem.fromJson(doc.data() as Map<String, dynamic>))
              .toList(),
        );
        filteredItems.clear();
        filteredItems.addAll(items); // Initialize filteredItems with all items
        isLoading = false;
      });

      // Initialize quantity controllers
      for (var item in items) {
        _quantityControllers[item.name] = TextEditingController();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading inventory: $e')));
    }
  }

  void _showAddItemDialog() {
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
  }

  void _addItem(String name) {
    if (isAdminLoggedIn) {
      setState(() {
        items.add(InventoryItem(name: name));
        filteredItems.add(InventoryItem(name: name)); // Add to filtered list
        _quantityControllers[name] =
            TextEditingController(); // Initialize controller
      });
      _saveInventory();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name added to Branch $selectedBranch inventory')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must log in as Admin to edit inventory')));
    }
  }

  Future<void> _saveInventory() async {
    try {
      for (var item in items) {
        await firestore
            .collection('inventory')
            .doc('branch_$selectedBranch')
            .collection('items')
            .doc(item.name)
            .set(item.toJson());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inventory saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving inventory: $e')));
      }
    }
  }

  void _updateQuantity(int index, String value) {
    if (isAdminLoggedIn) {
      int enteredQuantity = int.tryParse(value) ?? 0; // Parse the entered value
      if (enteredQuantity > 0) {
        // Ensure the entered value is valid
        setState(() {
          items[index].quantity +=
              enteredQuantity; // Add to the existing quantity
        });
        _saveInventory();
        _quantityControllers[items[index].name]
            ?.clear(); // Clear the input field
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must log in as Admin to edit inventory')));
    }
  }

  void _increaseQuantity(int index) {
    if (isAdminLoggedIn) {
      setState(() {
        items[index].quantity++;
      });
      _saveInventory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must log in as Admin to edit inventory')));
    }
  }

  void _decreaseQuantity(int index) {
    if (isAdminLoggedIn) {
      setState(() {
        if (items[index].quantity > 0) {
          items[index].quantity--;
        }
      });
      _saveInventory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must log in as Admin to edit inventory')));
    }
  }

  void _deleteItem(int index) async {
    if (isAdminLoggedIn) {
      String itemName = items[index].name;
      setState(() {
        items.removeAt(index);
        filteredItems.removeAt(index); // Remove from filtered list
        _quantityControllers.remove(itemName); // Remove the controller
      });

      try {
        await firestore
            .collection('inventory')
            .doc('branch_$selectedBranch')
            .collection('items')
            .doc(itemName)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '$itemName removed from Branch $selectedBranch inventory')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error removing $itemName: $e')));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must log in as Admin to edit inventory')));
    }
  }

  void _switchBranch(int branch) {
    setState(() {
      selectedBranch = branch;
      items.clear();
      filteredItems.clear();
      _quantityControllers.clear(); // Clear controllers when switching branches
      _loadInventory();
    });
  }

  void _filterItems(String query) {
    setState(() {
      filteredItems.clear();
      if (query.isEmpty) {
        filteredItems.addAll(items);
      } else {
        filteredItems.addAll(items
            .where(
                (item) => item.name.toLowerCase().contains(query.toLowerCase()))
            .toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Branch $selectedBranch Inventory'),
        actions: [
          if (!isAdminLoggedIn)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminLoginPage()),
                );
                if (result == true) {
                  _updateLoginStatus(true); // Log in as admin
                }
              },
            ),
          if (isAdminLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                _updateLoginStatus(false); // Log out
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
              },
            ),
          if (isAdminLoggedIn)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                _showAddItemDialog();
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: _filterItems,
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _switchBranch(1),
                        child: const Text('Main'),
                      ),
                      ElevatedButton(
                        onPressed: () => _switchBranch(2),
                        child: const Text('Upper SR'),
                      ),
                      ElevatedButton(
                        onPressed: () => _switchBranch(3),
                        child: const Text('Urdaneta'),
                      ),
                      ElevatedButton(
                        onPressed: () => _switchBranch(4),
                        child: const Text('La Union'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text('Quantity: ${item.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAdminLoggedIn)
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () {
                                    _decreaseQuantity(index);
                                  },
                                ),
                              SizedBox(
                                width: 30,
                                child: TextField(
                                  controller: _quantityControllers[
                                      item.name], // Use controller
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Qty',
                                  ),
                                  onSubmitted: (value) {
                                    _updateQuantity(index, value);
                                  },
                                ),
                              ),
                              if (isAdminLoggedIn)
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    _increaseQuantity(index);
                                  },
                                ),
                              if (isAdminLoggedIn)
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    _deleteItem(index);
                                  },
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
    );
  }
}
