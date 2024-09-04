import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_auth/firebase_auth.dart';
//new
class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _formulaController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _pharmacyController = TextEditingController();

  LatLng? _selectedLocation;
  String? _pharmacyName;
  String? _userName;
  Future<void>? _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/auth');
      });
      return;
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _userName = userDoc['name'];
          _pharmacyName = userDoc['pharmacyName'];
          _selectedLocation = userDoc['location'] != null
              ? LatLng(
                  userDoc['location'].latitude, userDoc['location'].longitude)
              : null;
          _pharmacyController.text = _pharmacyName ?? '';
        });
      });
    }
  }

  Future<void> _selectLocation() async {
    Location location = Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();

    setState(() {
      _selectedLocation =
          LatLng(_locationData.latitude!, _locationData.longitude!);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Location selected: (${_selectedLocation!.latitude}, ${_selectedLocation!.longitude})')),
    );
  }

  void _addMedicine() {
    final name = _nameController.text.trim();
    final formula = _formulaController.text.trim();
    final quantity = int.parse(_quantityController.text.trim());

    if (name.isNotEmpty &&
        formula.isNotEmpty &&
        quantity > 0 &&
        _pharmacyName != null) {
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a location first.')),
        );
        return;
      }

      FirebaseFirestore.instance.collection('medicines').add({
        'name': name,
        'formula': formula,
        'quantity': quantity,
        'pharmacyName': _pharmacyName,
        'location':
            GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
      });

      _nameController.clear();
      _formulaController.clear();
      _quantityController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medicine added successfully!')),
      );
    }
  }

  void _updateQuantity(DocumentSnapshot doc, int delta) {
    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot freshSnap = await transaction.get(doc.reference);
      int newQuantity = freshSnap['quantity'] + delta;
      if (newQuantity >= 0) {
        transaction.update(freshSnap.reference, {'quantity': newQuantity});
      }
    });
  }

  void _deleteMedicine(DocumentSnapshot doc) {
    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot freshSnap = await transaction.get(doc.reference);
      transaction.delete(freshSnap.reference);
    });
  }

  void _showLowStockDetails(List<DocumentSnapshot> lowStockMedicines) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Low Stock Medicines'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: lowStockMedicines.length,
              itemBuilder: (context, index) {
                var medicine = lowStockMedicines[index];
                return ListTile(
                  title: Text(medicine['name']),
                  subtitle: Text('Quantity: ${medicine['quantity']}'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inventory Page',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/auth');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FutureBuilder(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return Column(
              children: [
                if (_userName != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Welcome, $_userName',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Medicine Name',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.medical_services, color: Colors.teal),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _formulaController,
                        decoration: InputDecoration(
                          labelText: 'Formula',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.science, color: Colors.teal),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_list_numbered,
                              color: Colors.teal),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      if (_pharmacyName != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Pharmacy: $_pharmacyName',
                            style: TextStyle(
                                fontSize: 16,
                                color:
                                    const Color.fromARGB(255, 247, 248, 248)),
                          ),
                        ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _addMedicine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                        ),
                        child: Text('Add Medicine',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('medicines')
                        .where('pharmacyName', isEqualTo: _pharmacyName)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final medicines = snapshot.data!.docs;
                      final lowStockMedicines = medicines
                          .where((medicine) => medicine['quantity'] <= 2)
                          .toList();

                      return Column(
                        children: [
                          if (lowStockMedicines.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.warning,
                                  color: Colors.red, size: 30),
                              onPressed: () =>
                                  _showLowStockDetails(lowStockMedicines),
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: medicines.length,
                              itemBuilder: (context, index) {
                                var medicine = medicines[index];
                                return Card(
                                  margin: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  child: ListTile(
                                    title: Text(medicine['name'],
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal)),
                                    subtitle: Text(
                                        'Formula: ${medicine['formula']} \nQuantity: ${medicine['quantity']}',
                                        style: TextStyle(color: Colors.teal)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.remove_circle,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _updateQuantity(medicine, -1),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.add_circle,
                                              color: Colors.green),
                                          onPressed: () =>
                                              _updateQuantity(medicine, 1),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete,
                                              color: Colors.teal),
                                          onPressed: () =>
                                              _deleteMedicine(medicine),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
