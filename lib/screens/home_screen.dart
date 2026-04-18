import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/diet_tag.dart';
import '../models/venue_map_item.dart';
import '../services/user_preferences_service.dart';
import 'important_info_screen.dart';
import 'profile_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';
import 'venue_screen.dart';
import 'widgets/home_map_stack.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/oofy_bottom_nav.dart';

// home screen
class HomeScreen extends StatefulWidget {
  final int initialIndex;

  // default map start point
  static const LatLng defaultMapCenter = LatLng(55.4586, -4.6292);

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // current bottom nav index
  late int _index;

  // ui state
  bool _showFilters = false;
  bool _isSearching = false;
  bool _venuesLoaded = false;
  bool _showSuggestions = false;

  // search error
  String? _searchError;

  // selected filters
  final Set<DietTag> _selectedTags = <DietTag>{};

  // wait until map is ready before loading venue data
  final Completer<GoogleMapController> _mapCompleter =
  Completer<GoogleMapController>();

  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  BitmapDescriptor? _customMarkerIcon;

  // current zoom level
  double _currentZoom = 15;

  // cached cluster icons
  final Map<int, BitmapDescriptor> _clusterIconCache =
  <int, BitmapDescriptor>{};

  // venue and marker data
  List<VenueMapItem> _allVenues = <VenueMapItem>[];
  List<VenueMapItem> _searchSuggestions = <VenueMapItem>[];
  Set<Marker> _markers = <Marker>{};

  // hide extra map clutter
  static const String mapStyleHidePois = r'''
[
  { "featureType": "poi", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "poi.business", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "transit", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "administrative", "elementType": "labels", "stylers": [ { "visibility": "off" } ] }
]
''';

  // go to user location
  Future<void> _goToUserLocation() async {
    final controller = _mapController;
    if (controller == null) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('location services are disabled')),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('location permission denied')),
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('location permission permanently denied')),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLatLng,
            zoom: 17,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('could not get current location')),
      );
    }
  }

  // venues matching selected filters
  List<VenueMapItem> get _visibleVenues =>
      _allVenues.where(_venueMatchesSelectedFilters).toList();

  // suggestion names for ui
  List<String> get _suggestionNames =>
      _searchSuggestions.map((venue) => venue.name).toList();

  bool get _hasSearchText => _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;

    // load custom marker
    _loadCustomMarker();

    // update suggestions while typing
    _searchController.addListener(() {
      if (!mounted) return;
      _updateSuggestions(_searchController.text);
      setState(() {});
    });

    // load saved filters
    _loadSavedPreferences();

    // load venues once the map controller is ready
    _mapCompleter.future.then((_) => _loadAllVenues());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    final loadedTags = await UserPreferencesService.loadDietPreferences();

    if (!mounted) return;

    setState(() {
      _selectedTags
        ..clear()
        ..addAll(loadedTags);
    });
  }

  Future<void> _saveSelectedPreferences() async {
    await UserPreferencesService.saveDietPreferences(_selectedTags);
  }

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await _bitmapDescriptorFromAsset(
        'assets/images/marker_black.png',
        width: 78,
      );

      if (!mounted) return;

      setState(() {
        _customMarkerIcon = icon;
      });

      // rebuild markers if venues are already loaded
      if (_allVenues.isNotEmpty) {
        await _refreshMarkers();
      }
    } catch (_) {
      if (!mounted) return;

      // use default marker if custom one fails
      setState(() {
        _customMarkerIcon = BitmapDescriptor.defaultMarker;
      });

      if (_allVenues.isNotEmpty) {
        await _refreshMarkers();
      }
    }
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromAsset(
      String assetPath, {
        required int width,
      }) async {
    // load asset bytes
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    // resize marker image before using it on the map
    final resizedBytes = await _resizeImageBytes(
      bytes,
      targetWidth: width,
    );

    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  Future<Uint8List> _resizeImageBytes(
      Uint8List data, {
        required int targetWidth,
      }) async {
    // resize image for map marker
    final codec = await ui.instantiateImageCodec(
      data,
      targetWidth: targetWidth,
    );

    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;

    // small delay helps map style apply properly
    await Future.delayed(const Duration(milliseconds: 150));
    await controller.setMapStyle(mapStyleHidePois);

    if (!_mapCompleter.isCompleted) {
      _mapCompleter.complete(controller);
    }
  }

  void _onCameraMove(CameraPosition position) {
    // track zoom for clusters
    _currentZoom = position.zoom;
  }

  Future<void> _onCameraIdle() async {
    // rebuild markers after moving map so clusters update with zoom
    if (_allVenues.isEmpty) return;
    await _refreshMarkers();
  }

  Future<void> _loadAllVenues() async {
    try {
      // get venues from firestore
      final snap = await FirebaseFirestore.instance.collection('venues').get();

      final loadedVenues = snap.docs
          .map(_mapItemFromDoc)
          .whereType<VenueMapItem>()
          .toList();

      if (!mounted) return;

      _allVenues = loadedVenues;
      _venuesLoaded = true;

      // rebuild markers and fit map
      await _refreshMarkers();
      await _focusVisibleMarkers();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _venuesLoaded = true;
      });
    }
  }

  VenueMapItem? _mapItemFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();
    final name = (data['name'] ?? 'Venue').toString().trim();
    final geo = data['location'];

    // skip venues with no map location
    if (geo is! GeoPoint) {
      return null;
    }

    return VenueMapItem(
      id: doc.id,
      name: name.isEmpty ? 'Venue' : name,
      position: LatLng(geo.latitude, geo.longitude),
      tags: _parseTags(data),
    );
  }

  Set<DietTag> _parseTags(Map<String, dynamic> data) {
    final result = <DietTag>{};

    // support tag list
    final tagList = data['tagList'];
    if (tagList is List) {
      for (final tag in tagList) {
        final parsed = DietTagHelper.fromLooseText(tag.toString());
        if (parsed != null) result.add(parsed);
      }
    }

    // support tags map too
    final tagsMap = data['tags'];
    if (tagsMap is Map) {
      bool isTrue(String key) => tagsMap[key] == true;

      if (isTrue('glutenFree')) result.add(DietTag.glutenFree);
      if (isTrue('dairyFree')) result.add(DietTag.dairyFree);
      if (isTrue('vegetarian')) result.add(DietTag.vegetarian);
      if (isTrue('vegan')) result.add(DietTag.vegan);
    }

    return result;
  }

  bool _venueMatchesSelectedFilters(VenueMapItem venue) {
    // venue must match all selected filters
    if (_selectedTags.isEmpty) return false;
    return venue.tags.containsAll(_selectedTags);
  }

  double _clusterThresholdForZoom(double zoom) {
    // cluster size changes by zoom
    if (zoom >= 17.5) return 0.00045;
    if (zoom >= 16.5) return 0.00075;
    if (zoom >= 15.5) return 0.0012;
    if (zoom >= 14.5) return 0.0021;
    if (zoom >= 13.5) return 0.0038;
    if (zoom >= 12.5) return 0.0068;
    return 0.011;
  }

  double _distanceBetween(LatLng a, LatLng b) {
    final dx = a.latitude - b.latitude;
    final dy = a.longitude - b.longitude;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  LatLng _averagePosition(List<VenueMapItem> venues) {
    double latTotal = 0;
    double lngTotal = 0;

    for (final venue in venues) {
      latTotal += venue.position.latitude;
      lngTotal += venue.position.longitude;
    }

    // place cluster marker in the middle of its venues
    return LatLng(
      latTotal / venues.length,
      lngTotal / venues.length,
    );
  }

  List<VenueCluster> _buildClusters(List<VenueMapItem> venues) {
    final threshold = _clusterThresholdForZoom(_currentZoom);
    const minClusterSize = 6;

    final groupedClusters = <VenueCluster>[];

    for (final venue in venues) {
      int? matchedIndex;

      // try to add this venue into an existing nearby cluster
      for (int i = 0; i < groupedClusters.length; i++) {
        final cluster = groupedClusters[i];
        final distance = _distanceBetween(venue.position, cluster.position);

        if (distance <= threshold) {
          matchedIndex = i;
          break;
        }
      }

      if (matchedIndex == null) {
        groupedClusters.add(
          VenueCluster(
            venues: <VenueMapItem>[venue],
            position: venue.position,
          ),
        );
      } else {
        final updatedVenues = List<VenueMapItem>.from(
          groupedClusters[matchedIndex].venues,
        )..add(venue);

        groupedClusters[matchedIndex] = VenueCluster(
          venues: updatedVenues,
          position: _averagePosition(updatedVenues),
        );
      }
    }

    final finalClusters = <VenueCluster>[];

    for (final cluster in groupedClusters) {
      // keep real clusters only
      if (cluster.venues.length >= minClusterSize) {
        finalClusters.add(cluster);
        continue;
      }

      // otherwise show single markers
      for (final venue in cluster.venues) {
        finalClusters.add(
          VenueCluster(
            venues: <VenueMapItem>[venue],
            position: venue.position,
          ),
        );
      }
    }

    return finalClusters;
  }

  Future<BitmapDescriptor> _clusterIconForCount(int count) async {
    final cached = _clusterIconCache[count];
    if (cached != null) return cached;

    // draw dark cluster icon
    const double size = 128;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);

    final outerPaint = Paint()
      ..color = const Color(0x662E2E2E)
      ..isAntiAlias = true;

    final innerPaint = Paint()
      ..color = const Color(0xCC2E2E2E)
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..isAntiAlias = true;

    // outer circle
    canvas.drawCircle(center, 46, outerPaint);

    // main circle
    canvas.drawCircle(center, 36, innerPaint);

    // border
    canvas.drawCircle(center, 36, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - (textPainter.width / 2),
        center.dy - (textPainter.height / 2),
      ),
    );

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final icon = BitmapDescriptor.fromBytes(bytes);

    _clusterIconCache[count] = icon;
    return icon;
  }

  Future<void> _zoomToCluster(VenueCluster cluster) async {
    final controller = _mapController;
    if (controller == null) return;

    // zoom into cluster
    final nextZoom = math.min(_currentZoom + 2, 18.5);

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: cluster.position,
          zoom: nextZoom,
        ),
      ),
    );
  }

  Future<Set<Marker>> _buildMarkers() async {
    final clusters = _buildClusters(_visibleVenues);
    final markers = <Marker>{};

    for (final cluster in clusters) {
      if (cluster.isSingle) {
        final venue = cluster.venues.first;

        markers.add(
          Marker(
            markerId: MarkerId(venue.id),
            position: venue.position,
            icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow.noText,
            consumeTapEvents: true,
            onTap: () {
              // open venue screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VenueScreen(venueId: venue.id),
                ),
              );
            },
          ),
        );
      } else {
        final count = cluster.venues.length;
        final clusterIcon = await _clusterIconForCount(count);

        markers.add(
          Marker(
            markerId: MarkerId(
              'cluster_${cluster.position.latitude}_${cluster.position.longitude}_$count',
            ),
            position: cluster.position,
            icon: clusterIcon,
            consumeTapEvents: true,
            infoWindow: InfoWindow(
              title: '$count venues',
              snippet: 'tap to zoom in',
            ),
            onTap: () async {
              await _zoomToCluster(cluster);
            },
          ),
        );
      }
    }

    return markers;
  }

  Future<void> _refreshMarkers() async {
    if (!mounted) return;

    final builtMarkers = await _buildMarkers();

    if (!mounted) return;

    setState(() {
      _markers = builtMarkers;
    });
  }

  Future<void> _moveCamera(LatLng target, double zoom) async {
    // move map camera
    _currentZoom = zoom;

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: zoom,
        ),
      ),
    );
  }

  Future<void> _focusVisibleMarkers() async {
    final visibleVenues = _visibleVenues;

    // no matching venues
    if (visibleVenues.isEmpty) {
      await _moveCamera(HomeScreen.defaultMapCenter, 13);
      return;
    }

    // one matching venue
    if (visibleVenues.length == 1) {
      await _moveCamera(visibleVenues.first.position, 16);
      return;
    }

    // work out map bounds for all visible venues
    double minLat = visibleVenues.first.position.latitude;
    double maxLat = visibleVenues.first.position.latitude;
    double minLng = visibleVenues.first.position.longitude;
    double maxLng = visibleVenues.first.position.longitude;

    for (final venue in visibleVenues.skip(1)) {
      final lat = venue.position.latitude;
      final lng = venue.position.longitude;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  Future<void> _zoomIn() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomOut());
  }

  void _hideOverlays() {
    // hide filters and suggestions
    setState(() {
      _showFilters = false;
      _showSuggestions = false;
    });
  }

  void _hideSuggestions() {
    if (!_showSuggestions) return;

    setState(() {
      _showSuggestions = false;
    });
  }

  void _clearSearch() {
    // clear search state
    setState(() {
      _searchController.clear();
      _searchError = null;
      _showSuggestions = false;
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
      _showSuggestions = false;
    });
  }

  void _updateSuggestions(String raw) {
    final query = raw.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = <VenueMapItem>[];
        _showSuggestions = false;
        _searchError = null;
      });
      return;
    }

    // simple local venue search
    final matches = _allVenues.where((venue) {
      final name = venue.name.toLowerCase();
      final words = name.split(' ');

      // match whole name or the start of any word
      return name.contains(query) || words.any((word) => word.startsWith(query));
    }).take(6).toList();

    setState(() {
      _searchSuggestions = matches;
      _showSuggestions = matches.isNotEmpty;
      _searchError = null;
    });
  }

  VenueMapItem? _findBestVenueMatch(String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return null;

    // exact match first
    for (final venue in _allVenues) {
      if (venue.name.toLowerCase() == query) return venue;
    }

    // then starts with
    for (final venue in _allVenues) {
      if (venue.name.toLowerCase().startsWith(query)) return venue;
    }

    // then contains
    for (final venue in _allVenues) {
      if (venue.name.toLowerCase().contains(query)) return venue;
    }

    return null;
  }

  Future<void> _selectSuggestion(VenueMapItem venue) async {
    // fill search box
    _searchController.text = venue.name;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );

    setState(() {
      _showSuggestions = false;
      _searchError = null;
      _showFilters = false;
    });

    // move to venue
    await _moveCamera(venue.position, 16);
  }

  Future<void> _handleSuggestionTap(int index) async {
    if (index < 0 || index >= _searchSuggestions.length) return;
    await _selectSuggestion(_searchSuggestions[index]);
  }

  Future<void> _onSearchSubmitted(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _searchError = null;
      _showFilters = false;
      _showSuggestions = false;
    });

    try {
      // try venue match first
      final localMatch = _findBestVenueMatch(query);

      if (localMatch != null) {
        await _selectSuggestion(localMatch);
      } else {
        // try geocoding if no venue match
        final moved = await _geocodeAndMoveMap(query);

        if (!moved && mounted) {
          setState(() {
            _searchError = 'No results for "$query"';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Search failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<bool> _geocodeAndMoveMap(String query) async {
    // turn search text into coordinates
    final locations = await locationFromAddress(query);

    if (locations.isEmpty) return false;

    final latLng = LatLng(
      locations.first.latitude,
      locations.first.longitude,
    );

    await _moveCamera(latLng, 14);
    return true;
  }

  Future<void> _handleFilterChanged(DietTag tag, bool checked) async {
    final nextTags = Set<DietTag>.from(_selectedTags);

    if (checked) {
      nextTags.add(tag);
    } else {
      nextTags.remove(tag);
    }

    // keep at least one filter
    if (nextTags.isEmpty) {
      return;
    }

    setState(() {
      _selectedTags
        ..clear()
        ..addAll(nextTags);
    });

    await _saveSelectedPreferences();

    // refresh markers after filter change
    await _refreshMarkers();
    await _focusVisibleMarkers();
  }

  Widget _buildMapTab() {
    return SafeArea(
      child: Column(
        children: [
          HomeTopBar(
            controller: _searchController,
            isSearching: _isSearching,
            hasSearchText: _hasSearchText,
            showSuggestions: _showSuggestions,
            suggestionNames: _suggestionNames,
            onSubmitted: _onSearchSubmitted,
            onClearSearch: _clearSearch,
            onToggleFilters: _toggleFilters,
            onSuggestionTap: _handleSuggestionTap,
            onSearchTap: () {
              // reopen suggestions
              if (_searchSuggestions.isNotEmpty) {
                setState(() {
                  _showSuggestions = true;
                });
              }
            },
          ),
          Expanded(
            child: HomeMapStack(
              markers: _markers,
              showFilters: _showFilters,
              venuesLoaded: _venuesLoaded,
              hasVenues: _allVenues.isNotEmpty,
              hasVisibleMarkers: _markers.isNotEmpty,
              searchError: _searchError,
              selectedTags: _selectedTags,
              onMapCreated: _onMapCreated,
              onMapTap: (_) => _hideSuggestions(),
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              onFocusMarkers: _focusVisibleMarkers,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onCenterButtonTap: () async {
                _hideOverlays();
                await _goToUserLocation();
              },
              onFilterChanged: _handleFilterChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: IndexedStack(
        index: _index,
        children: [
          _buildMapTab(),
          const ImportantInfoScreen(),
          const ReviewsScreen(),
          const ProfileScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: OofyBottomNav(
        currentIndex: _index,
        onTap: (i) {
          setState(() {
            _index = i;
            _showSuggestions = false;
          });
        },
      ),
    );
  }
}