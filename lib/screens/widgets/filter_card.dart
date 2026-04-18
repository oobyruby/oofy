import 'package:flutter/material.dart';

import '../../models/diet_tag.dart';

// small filter dropdown used on the map screen
// lets user toggle dietary tags on/off
class FilterCard extends StatelessWidget {
  final Set<DietTag> selected;
  final Future<void> Function(DietTag tag, bool checked) onChanged;

  const FilterCard({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // slightly transparent dark background
      color: const Color(0xCC2E2E2E),
      borderRadius: BorderRadius.circular(10),
      elevation: 4,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,

          // builds a row for each diet tag
          children: DietTag.values.map((tag) {
            return Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    // checked if tag is currently selected
                    value: selected.contains(tag),

                    // updates filter state in parent
                    onChanged: (value) => onChanged(tag, value ?? false),

                    // makes checkbox smaller and tighter
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),

                    checkColor: Colors.black,
                    activeColor: Colors.white,
                    side: const BorderSide(
                      color: Colors.white70,
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // tag label text
                Text(
                  DietTagHelper.labels[tag]!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}