import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'admin_login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InventoryItem {
  String name;
  int quantity;
  DateTime shipmentDate; // New field for shipment date

  InventoryItem({
    required this.name,
    this.quantity = 0,
    DateTime? shipmentDate, // Optional parameter
  }) : shipmentDate = shipmentDate ?? DateTime.now(); // Default to current date

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'shipmentDate':
          shipmentDate.toIso8601String(), // Convert DateTime to String
    };
  }

  static InventoryItem fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name'],
      quantity: json['quantity'],
      shipmentDate: json['shipmentDate'] != null
          ? DateTime.parse(json['shipmentDate']) // Parse if not null
          : DateTime.now(), // Default to current date if null
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
  String selectedBranch = "Main";
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

  void _sortItems(String sortBy) {
    setState(() {
      if (sortBy == 'quantityLowToHigh') {
        filteredItems
            .sort((a, b) => a.quantity.compareTo(b.quantity)); // Low to High
      } else if (sortBy == 'quantityHighToLow') {
        filteredItems
            .sort((a, b) => b.quantity.compareTo(a.quantity)); // High to Low
      } else if (sortBy == 'shipmentDate') {
        filteredItems.sort((a, b) =>
            a.shipmentDate.compareTo(b.shipmentDate)); // By Shipment Date
      }
    });
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sort By'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Quantity: Low to High'),
                onTap: () {
                  _sortItems('quantityLowToHigh');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('Quantity: High to Low'),
                onTap: () {
                  _sortItems('quantityHighToLow');
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: const Text('Shipment Date'),
                onTap: () {
                  _sortItems('shipmentDate');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
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

  void _showEditShipmentDateDialog(int index) async {
    if (!isAdminLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must log in as Admin to edit the shipment date')));
      return;
    }

    final item = items[index];
    final DateTime? newDate = await showDatePicker(
      context: context,
      initialDate: item.shipmentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (newDate != null) {
      setState(() {
        item.shipmentDate = newDate; // Update the shipment date
      });

      // Save to Firestore
      try {
        await firestore
            .collection('inventory')
            .doc(selectedBranch)
            .collection('items')
            .doc(item.name)
            .update({
          'shipmentDate': newDate.toIso8601String(), // Update date in Firestore
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Shipment date updated successfully!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating shipment date: $e')));
        }
      }
    }
  }

  Future<void> _loadInventory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final QuerySnapshot snapshot = await firestore
          .collection('inventory')
          .doc(selectedBranch)
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

      // Check for low stock items and trigger notifications
      for (var item in items) {
        if (item.quantity <= 10) {
          _showLowStockNotification(item.name, item.quantity);
        }
      }

      // Initialize quantity controllers
      for (var item in items) {
        _quantityControllers[item.name] = TextEditingController();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading inventory: $e')));
      }
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

  void _addItem(String name) async {
    if (isAdminLoggedIn) {
      if (items.any((item) => item.name == name)) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name already exists in the inventory')));
        return;
      }

      // Create a new item with the current date as the shipment date
      final newItem = InventoryItem(name: name, quantity: 0);

      // Update the local state
      setState(() {
        items.add(newItem);
        filteredItems.add(newItem);
        _quantityControllers[name] = TextEditingController();
      });

      // Save to Firestore
      try {
        await firestore
            .collection('inventory')
            .doc(selectedBranch)
            .collection('items')
            .doc(name)
            .set(newItem.toJson());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('$name added to Branch $selectedBranch inventory')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error adding $name: $e')));
        }
      }
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
            .doc(selectedBranch) // Use the branch name directly
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

  void _updateQuantity(int index, String value) async {
    if (isAdminLoggedIn) {
      int enteredQuantity = int.tryParse(value) ?? 0;

      if (enteredQuantity > 0) {
        setState(() {
          items[index].quantity += enteredQuantity;
          items[index].shipmentDate =
              DateTime.now(); // Update the shipment date
        });

        // Save to Firestore
        try {
          await firestore
              .collection('inventory')
              .doc(selectedBranch)
              .collection('items')
              .doc(items[index].name)
              .update({
            'quantity': items[index].quantity,
            'shipmentDate': items[index].shipmentDate.toIso8601String(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Quantity updated successfully!')));
          }

          // Check for low stock and trigger notification
          if (items[index].quantity <= 10) {
            _showLowStockNotification(items[index].name, items[index].quantity);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating quantity: $e')));
          }
        }

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

  void _showLowStockNotification(String itemName, int quantity) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'low_stock_channel', // Channel ID
      'Low Stock Notifications', // Channel name
      importance: Importance.high,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Low Stock Alert', // Title
      '$itemName is low in stock. Current quantity: $quantity', // Body
      platformChannelSpecifics,
    );
  }

  void _decreaseQuantity(int index) {
    if (isAdminLoggedIn) {
      final String inputValue =
          _quantityControllers[items[index].name]?.text ?? '0';
      final int enteredQuantity = int.tryParse(inputValue) ?? 0;

      setState(() {
        if (items[index].quantity >= enteredQuantity) {
          items[index].quantity -=
              enteredQuantity; // Subtract the entered quantity
        } else {
          items[index].quantity = 0; // Prevent negative quantities
        }
        _quantityControllers[items[index].name]
            ?.clear(); // Clear the input field
      });

      // Save to Firestore
      _saveInventory();

      // Check for low stock and trigger notification
      if (items[index].quantity <= 10) {
        _showLowStockNotification(items[index].name, items[index].quantity);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must log in as Admin to edit inventory')));
    }
  }

  void _increaseQuantity(int index) {
    if (isAdminLoggedIn) {
      final String inputValue =
          _quantityControllers[items[index].name]?.text ?? '0';
      final int enteredQuantity = int.tryParse(inputValue) ?? 0;

      setState(() {
        items[index].quantity += enteredQuantity; // Add the entered quantity
        _quantityControllers[items[index].name]
            ?.clear(); // Clear the input field
      });
      _saveInventory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must log in as Admin to edit inventory')));
    }
  }

  void _deleteItem(int index) async {
    if (isAdminLoggedIn) {
      final bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this item?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      String itemName = items[index].name;

      try {
        // Delete the item from Firestore
        await firestore
            .collection('inventory')
            .doc(selectedBranch)
            .collection('items')
            .doc(itemName)
            .delete();

        // Refresh the inventory from Firestore
        await _loadInventory();

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

  void _switchBranch(String branch) {
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

  Widget _buildBranchButton(String branch) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () => _switchBranch(branch),
        style: ElevatedButton.styleFrom(
          backgroundColor: selectedBranch == branch
              ? Colors.blue // Highlight color for selected branch
              : Colors.grey[300], // Default color for unselected branches
          foregroundColor: selectedBranch == branch
              ? Colors.white // Text color for selected branch
              : Colors.black, // Text color for unselected branches
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(branch),
      ),
    );
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
                  _loadInventory(); // Reload inventory to ensure UI updates
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
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog, // Open the sorting dialog
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
                      _buildBranchButton('Main'),
                      _buildBranchButton('Upper SR'),
                      _buildBranchButton('Urdaneta'),
                      _buildBranchButton('La Union'),
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
                          subtitle: isAdminLoggedIn
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Quantity: ${item.quantity}'),
                                    InkWell(
                                      onTap: () {
                                        _showEditShipmentDateDialog(index);
                                      },
                                      child: Text(
                                        'Shipment Receive: ${_formatDate(item.shipmentDate)}',
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : null, // Hide subtitle in view-only mode
                          trailing: isAdminLoggedIn
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        _decreaseQuantity(index);
                                      },
                                    ),
                                    SizedBox(
                                      width: 50,
                                      child: TextField(
                                        controller:
                                            _quantityControllers[item.name],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          hintText: 'Qty',
                                          border: OutlineInputBorder(),
                                        ),
                                        onSubmitted: (value) {
                                          _updateQuantity(index, value);
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        _increaseQuantity(index);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () {
                                        _deleteItem(index);
                                      },
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Quantity: ${item.quantity}'),
                                    Text(
                                      'Shipment Receive: ${_formatDate(item.shipmentDate)}',
                                      style: const TextStyle(
                                        color: Colors.blueGrey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ), // Show quantity and shipment date on the right in view-only mode
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
