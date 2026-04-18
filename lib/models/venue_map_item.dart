import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'diet_tag.dart';

// map venue model used by the home screen
class VenueMapItem {
  final String id;
  final String name;
  final LatLng position;
  final Set<DietTag> tags;

  const VenueMapItem({
    required this.id,
    required this.name,
    required this.position,
    required this.tags,
  });
}

// cluster object for grouped venues
class VenueCluster {
  final List<VenueMapItem> venues;
  final LatLng position;

  const VenueCluster({
    required this.venues,
    required this.position,
  });

  bool get isSingle => venues.length == 1;
}