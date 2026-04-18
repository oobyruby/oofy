import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/diet_tag.dart';

// handles reading and writing saved dietary preferences
class UserPreferencesService {
  static Future<Set<DietTag>> loadDietPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return <DietTag>{DietTag.glutenFree};
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? <String, dynamic>{};
      final rawPreferences = data['dietPreferences'];

      final loadedTags = <DietTag>{};

      if (rawPreferences is List) {
        for (final value in rawPreferences) {
          final tag = DietTagHelper.fromStoredValue(value.toString());
          if (tag != null) {
            loadedTags.add(tag);
          }
        }
      }

      // fallback for older users who do not have preferences saved yet
      if (loadedTags.isEmpty) {
        loadedTags.add(DietTag.glutenFree);
        await saveDietPreferences(loadedTags);
      }

      return loadedTags;
    } catch (_) {
      // fallback keeps the app usable if firestore read fails
      return <DietTag>{DietTag.glutenFree};
    }
  }

  static Future<void> saveDietPreferences(Set<DietTag> tags) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (tags.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'dietPreferences': tags.map(DietTagHelper.toStoredValue).toList(),
      'hasChosenDietPreferences': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}