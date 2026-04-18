import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// top bar
class VenueHeaderBar extends StatelessWidget {
  final VoidCallback onBack;

  const VenueHeaderBar({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Spacer(),
        const Text(
          'oofy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }
}

// map preview
class VenueMapPreview extends StatelessWidget {
  final String venueId;
  final String venueName;
  final LatLng? venueLatLng;

  const VenueMapPreview({
    super.key,
    required this.venueId,
    required this.venueName,
    required this.venueLatLng,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 250,
        child: venueLatLng != null
            ? AbsorbPointer(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: venueLatLng!,
              zoom: 16,
            ),
            markers: {
              Marker(
                markerId: MarkerId(venueId),
                position: venueLatLng!,
                infoWindow: InfoWindow(title: venueName),
                icon: BitmapDescriptor.defaultMarker,
              ),
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
        )
            : Container(
          color: const Color(0xFF3A3A3A),
          child: const Center(
            child: Text(
              'No map location set',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// action button
class VenueActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const VenueActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF4A4A4A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// section card
class VenueSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const VenueSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// tag chip
class VenueTagChip extends StatelessWidget {
  final String text;

  const VenueTagChip({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF505050),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// rating stars
class VenueStars extends StatelessWidget {
  final double average;

  const VenueStars({
    super.key,
    required this.average,
  });

  @override
  Widget build(BuildContext context) {
    final rounded = average.round().clamp(0, 5);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            index < rounded ? Icons.star : Icons.star_border,
            color: Colors.white,
            size: 18,
          ),
        );
      }),
    );
  }
}
