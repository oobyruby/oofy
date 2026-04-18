// fixed set of dietary tags used across the app
enum DietTag { glutenFree, dairyFree, vegetarian, vegan }

// shared helpers for displaying and storing diet tags
class DietTagHelper {
  static const Map<DietTag, String> labels = {
    DietTag.glutenFree: 'gluten free',
    DietTag.dairyFree: 'dairy free',
    DietTag.vegetarian: 'vegetarian',
    DietTag.vegan: 'vegan',
  };

  static String toStoredValue(DietTag tag) {
    switch (tag) {
      case DietTag.glutenFree:
        return 'glutenFree';
      case DietTag.dairyFree:
        return 'dairyFree';
      case DietTag.vegetarian:
        return 'vegetarian';
      case DietTag.vegan:
        return 'vegan';
    }
  }

  static DietTag? fromStoredValue(String raw) {
    switch (raw.trim()) {
      case 'glutenFree':
        return DietTag.glutenFree;
      case 'dairyFree':
        return DietTag.dairyFree;
      case 'vegetarian':
        return DietTag.vegetarian;
      case 'vegan':
        return DietTag.vegan;
    }

    return null;
  }

  static DietTag? fromLooseText(String raw) {
    final normalised = raw.trim().toLowerCase().replaceAll(' ', '');

    switch (normalised) {
      case 'glutenfree':
        return DietTag.glutenFree;
      case 'dairyfree':
        return DietTag.dairyFree;
      case 'vegetarian':
        return DietTag.vegetarian;
      case 'vegan':
        return DietTag.vegan;
    }

    return null;
  }
}