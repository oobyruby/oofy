import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// venue load result
class BusinessVenueLoadResult {
  final String? venueId;
  final Map<String, dynamic>? venueData;
  final String? errorMessage;

  const BusinessVenueLoadResult({
    required this.venueId,
    required this.venueData,
    required this.errorMessage,
  });

  // something went wrong
  bool get hasError => errorMessage != null;

  // venue loaded ok
  bool get hasVenue => venueId != null && venueData != null;
}

// venue loader for business screens
class BusinessVenueLoader {
  static Future<BusinessVenueLoadResult> loadManagedVenue() async {
    try {
      // current user
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return const BusinessVenueLoadResult(
          venueId: null,
          venueData: null,
          errorMessage: 'No logged in user found.',
        );
      }

      // get user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return const BusinessVenueLoadResult(
          venueId: null,
          venueData: null,
          errorMessage: 'User profile not found.',
        );
      }

      final userData = userDoc.data();

      // linked venue id
      final managedVenueId = userData?['managedVenueId'];

      // no linked venue
      if (managedVenueId == null ||
          managedVenueId.toString().trim().isEmpty) {
        return const BusinessVenueLoadResult(
          venueId: null,
          venueData: null,
          errorMessage: 'No venue linked to this business account.',
        );
      }

      // get venue doc
      final venueDoc = await FirebaseFirestore.instance
          .collection('venues')
          .doc(managedVenueId.toString())
          .get();

      if (!venueDoc.exists) {
        return const BusinessVenueLoadResult(
          venueId: null,
          venueData: null,
          errorMessage: 'Linked venue not found.',
        );
      }

      // return venue data
      return BusinessVenueLoadResult(
        venueId: venueDoc.id,
        venueData: venueDoc.data(),
        errorMessage: null,
      );
    } catch (e) {
      // load failed
      return BusinessVenueLoadResult(
        venueId: null,
        venueData: null,
        errorMessage: 'Failed to load venue data: $e',
      );
    }
  }
}