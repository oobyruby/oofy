import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/diet_tag.dart';
import '../home_screen.dart';
import 'filter_card.dart';
import 'map_buttons.dart';

// main map layer for the home screen
// handles map + overlays (filters, buttons, status messages)
class HomeMapStack extends StatelessWidget {
  final Set<Marker> markers;
  final bool showFilters;
  final bool venuesLoaded;
  final bool hasVenues;
  final bool hasVisibleMarkers;
  final String? searchError;
  final Set<DietTag> selectedTags;
  final Future<void> Function(GoogleMapController controller) onMapCreated;
  final ValueChanged<LatLng> onMapTap;
  final ValueChanged<CameraPosition> onCameraMove;
  final Future<void> Function() onCameraIdle;
  final Future<void> Function() onFocusMarkers;
  final Future<void> Function() onZoomIn;
  final Future<void> Function() onZoomOut;
  final Future<void> Function() onCenterButtonTap;
  final Future<void> Function(DietTag tag, bool checked) onFilterChanged;

  const HomeMapStack({
    super.key,
    required this.markers,
    required this.showFilters,
    required this.venuesLoaded,
    required this.hasVenues,
    required this.hasVisibleMarkers,
    required this.searchError,
    required this.selectedTags,
    required this.onMapCreated,
    required this.onMapTap,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onFocusMarkers,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenterButtonTap,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // full screen google map
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: HomeScreen.defaultMapCenter,
              zoom: 15,
            ),
            onMapCreated: (controller) => onMapCreated(controller),
            onTap: onMapTap,
            onCameraMove: onCameraMove,
            onCameraIdle: () => onCameraIdle(),
            markers: markers,

            // custom ui
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,

            // gestures enabled
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
        ),

        // filter dropdown (top centre)
        if (showFilters)
          Positioned(
            top: 18,
            left: 0,
            right: 0,
            child: Center(
              child: FilterCard(
                selected: selectedTags,
                onChanged: onFilterChanged,
              ),
            ),
          ),

        // map control buttons (top right)
        Positioned(
          right: 16,
          top: 16,
          child: Column(
            children: [
              SquareMapButton(
                icon: Icons.near_me,
                onTap: onCenterButtonTap,
              ),
              const SizedBox(height: 10),
              SquareMapButton(
                icon: Icons.add,
                onTap: onZoomIn,
              ),
              const SizedBox(height: 10),
              SquareMapButton(
                icon: Icons.remove,
                onTap: onZoomOut,
              ),
            ],
          ),
        ),

        // helper messages
        if (searchError != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: _InfoPill(text: searchError!),
          )
        else if (venuesLoaded && !hasVenues)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: _InfoPill(text: 'no venues found'),
          )
        else if (venuesLoaded && hasVenues && !hasVisibleMarkers)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: _InfoPill(text: 'no venues match your selected filters'),
            ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;

  const _InfoPill({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC2E2E2E),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}