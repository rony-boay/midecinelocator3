import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;

class MapScreen extends StatefulWidget {
  final latLng.LatLng? userLocation;
  final List<DocumentSnapshot> searchResults;

  MapScreen({required this.userLocation, required this.searchResults});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Marker> markers = [];

  @override
  void initState() {
    super.initState();
    _setMarkers();
  }

  void _setMarkers() {
    if (widget.userLocation != null) {
      markers.add(
        Marker(
          point: widget.userLocation!,
          width: 100,
          height: 80,
          builder: (ctx) => Column(
            children: [
              Text(
                'You are here',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.white,
                ),
              ),
              Icon(
                Icons.location_pin,
                color: Colors.blue,
                size: 40,
              ),
            ],
          ),
        ),
      );
    }

    final markerPositions = <latLng.LatLng, int>{};

    for (var result in widget.searchResults) {
      try {
        final geoPoint = result['location'] as GeoPoint?;
        final pharmacyName = result['pharmacyName'] as String?;

        if (geoPoint != null && pharmacyName != null) {
          final latLng.LatLng position = latLng.LatLng(geoPoint.latitude, geoPoint.longitude);

          if (markerPositions.containsKey(position)) {
            markerPositions[position] = markerPositions[position]! + 1;
          } else {
            markerPositions[position] = 0;
          }

          final offsetPosition = _calculateOffsetPosition(position, markerPositions[position]!);

          markers.add(
            Marker(
              point: offsetPosition,
              width: 100,
              height: 80,
              builder: (ctx) => Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: Text(
                      pharmacyName,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ],
              ),
            ),
          );
        } else {
          print('No location data for document: ${result.id}');
        }
      } catch (e) {
        print('Error adding marker for document: ${result.id}, Error: $e');
      }
    }
  }

  latLng.LatLng _calculateOffsetPosition(latLng.LatLng originalPosition, int offsetCount) {
    const double offsetStep = 0.00002;
    const double angleStep = 15.0;

    double angle = angleStep * offsetCount;
    double radian = angle * (pi / 180.0);

    double latOffset = offsetStep * offsetCount * cos(radian);
    double lngOffset = offsetStep * offsetCount * sin(radian);

    return latLng.LatLng(
      originalPosition.latitude + latOffset,
      originalPosition.longitude + lngOffset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map View'),
      ),
      body: widget.userLocation == null
          ? Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                center: widget.userLocation,
                zoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: markers,
                ),
              ],
            ),
    );
  }
}
