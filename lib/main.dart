import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:midecinelocator3/ScheduleNotificationScreen.dart';
import 'package:midecinelocator3/map_screen.dart';
import 'inventory_page.dart';
import 'auth_page.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:latlong2/latlong.dart' as latLng;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await Firebase.initializeApp();

  tz.initializeTimeZones();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'M E D L O C',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
            .copyWith(secondary: Colors.orange),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => UserScreen(),
        '/inventory': (context) => InventoryPage(),
        '/auth': (context) => AuthPage(),
        '/user': (context) => UserScreen(),
        '/schedule': (context) => ScheduleNotificationScreen(),
      },
    );
  }
}

// class AuthCheck extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(child: CircularProgressIndicator());
//         } else if (snapshot.hasData) {
//           return InventoryPage();
//         } else {
//           return AuthPage();
//         }
//       },
//     );
//   }
// }

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  List<DocumentSnapshot> _formulaResults = [];
  latLng.LatLng? _userLocation;
  bool _isLoading = false;
  int _currentPage = 0;
  final int _resultsPerPage = 5;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
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
      _userLocation =
          latLng.LatLng(_locationData.latitude!, _locationData.longitude!);
    });
  }

  Future<void> _searchMedicine() async {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      if (_userLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your location')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _searchResults = [];
        _formulaResults = [];
        _currentPage = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Searching for medicine')),
      );

      try {
        // Search for the specific medicine name
        final nameResults = await FirebaseFirestore.instance
            .collection('medicines')
            .where('name', isEqualTo: query)
            .get();

        List<DocumentSnapshot> availableResults = nameResults.docs
            .where((doc) => doc['quantity'] != null && doc['quantity'] > 0)
            .toList();

        if (availableResults.isEmpty) {
          // If no available medicines by name, attempt to retrieve the formula of any matched medicines
          final formulaSearchResults = await FirebaseFirestore.instance
              .collection('medicines')
              .where('name', isEqualTo: query)
              .get();

          List formulas = formulaSearchResults.docs
              .where((doc) => doc['formula'] != null)
              .map((doc) => doc['formula'])
              .toList();

          if (formulas.isNotEmpty) {
            // Search by the formulas retrieved from the initial name-based search
            final formulaSearch = await FirebaseFirestore.instance
                .collection('medicines')
                .where('formula', whereIn: formulas)
                .get();

            setState(() {
              _formulaResults = formulaSearch.docs
                  .where(
                      (doc) => doc['quantity'] != null && doc['quantity'] > 0)
                  .toList();
            });
          }
        } else {
          setState(() {
            _searchResults = availableResults;
          });
        }

        if (_searchResults.isEmpty && _formulaResults.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Medicine not available')));
        } else {
          await _sortResultsByProximity();
        }
      } catch (e) {
        print('Error searching for medicine: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for medicine: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a medicine name'),
        ),
      );
    }
  }

  Future<void> _sortResultsByProximity() async {
    if (_userLocation != null) {
      List<DocumentSnapshot> allResults = [];
      if (_searchResults.isNotEmpty) {
        allResults.addAll(_searchResults);
      }
      if (_formulaResults.isNotEmpty) {
        allResults.addAll(_formulaResults);
      }

      // Calculate distances and sort
      allResults.sort((a, b) {
        final geoPointA = a['location'] as GeoPoint?;
        final geoPointB = b['location'] as GeoPoint?;

        if (geoPointA == null || geoPointB == null) {
          return 0;
        }

        final distanceA = _calculateDistance(_userLocation!,
            latLng.LatLng(geoPointA.latitude, geoPointA.longitude));
        final distanceB = _calculateDistance(_userLocation!,
            latLng.LatLng(geoPointB.latitude, geoPointB.longitude));

        return distanceA.compareTo(distanceB);
      });

      setState(() {
        _searchResults = allResults;
      });
    }
  }

  double _calculateDistance(latLng.LatLng point1, latLng.LatLng point2) {
    final Distance distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      point1,
      point2,
    );
  }

  Future<void> _pickImageForSearch() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final inputImage = InputImage.fromFilePath(pickedFile.path);
        final textRecognizer = TextRecognizer();
        final RecognizedText recognizedText =
            await textRecognizer.processImage(inputImage);
        if (recognizedText.text.isNotEmpty) {
          setState(() {
            _searchController.text = recognizedText.text;
          });
          await _searchMedicine();
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to open camera: $e')));
    }
  }

  void _showMap(DocumentSnapshot document) {
    final geoPoint = document['location'] as GeoPoint?;
    if (geoPoint != null && _userLocation != null) {
      final latLng.LatLng pharmacyLocation =
          latLng.LatLng(geoPoint.latitude, geoPoint.longitude);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            userLocation: _userLocation,
            searchResults: [document],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Location data not available')));
    }
  }

  Future<void> _selectLocation() async {
    // Ensure current location is used even if the user doesn't manually select it
    if (_userLocation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location already set')),
      );
      return;
    }

    await _getCurrentLocation();
    if (_userLocation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location selected')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(183, 237, 231, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 39, 198, 57),
        title: const Center(
          child: Text(
            'M E D L O C',
            style: TextStyle(color: Color.fromARGB(255, 11, 11, 11)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _selectLocation,
            tooltip: 'Select Location',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16.0),
            IconButton(
              icon: const Icon(
                Icons.medical_services,
                size: 100,
                color: Colors.teal,
              ),
              onPressed: () {},
            ),
          
            const SizedBox(height: 16.0),
            // Centered Search Bar
            Center(
              child: Card(
                color: const Color.fromRGBO(183, 237, 231, 1),
                elevation: 18,
                shadowColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search Medicine',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _pickImageForSearch,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: _searchMedicine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: const Text(
                          'Search',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 16.0),
                      // Navigation Icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.inventory,
                              size: 40,
                              color: Colors.teal,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/inventory');
                            },
                            tooltip: 'Inventory',
                          ),
                          const SizedBox(width: 16.0),
                          IconButton(
                            icon: const Icon(
                              Icons.alarm,
                              size: 40,
                              color: Colors.teal,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/schedule');
                            },
                            tooltip: 'Schedule Reminder',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Display search results
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final document = _searchResults[index];
                  return Card(
                    elevation: 18,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: ListTile(
                      title: Text(document['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quantity: ${document['quantity']}'),
                          Text('Formula: ${document['formula']}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.map),
                        onPressed: () => _showMap(document),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
