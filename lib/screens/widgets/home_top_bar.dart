import 'package:flutter/material.dart';

// top section on the home screen
// includes app title, search bar, suggestions, and filter button
class HomeTopBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final bool hasSearchText;
  final bool showSuggestions;
  final List<String> suggestionNames;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onToggleFilters;
  final VoidCallback onSearchTap;
  final Future<void> Function(int index) onSuggestionTap;

  const HomeTopBar({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.hasSearchText,
    required this.showSuggestions,
    required this.suggestionNames,
    required this.onSubmitted,
    required this.onClearSearch,
    required this.onToggleFilters,
    required this.onSearchTap,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          // app title
          const Text(
            'oofy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // search input
          _SearchBar(
            controller: controller,
            isSearching: isSearching,
            hasSearchText: hasSearchText,
            onSubmitted: onSubmitted,
            onClearSearch: onClearSearch,
            onTap: onSearchTap,
          ),

          // dropdown suggestions under the search bar
          _SuggestionsCard(
            showSuggestions: showSuggestions,
            suggestionNames: suggestionNames,
            onSuggestionTap: onSuggestionTap,
          ),

          const SizedBox(height: 8),

          // filter toggle button
          GestureDetector(
            onTap: onToggleFilters,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.tune, color: Colors.white70, size: 16),
                SizedBox(width: 6),
                Text(
                  'Filter',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final bool hasSearchText;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onTap;

  const _SearchBar({
    required this.controller,
    required this.isSearching,
    required this.hasSearchText,
    required this.onSubmitted,
    required this.onClearSearch,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // rounded search bar used on the map screen
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A4A),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.search,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 8),

          // text input for venue or area search
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Search for a venue or area',
                hintStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onTap: onTap,
              onSubmitted: onSubmitted,
            ),
          ),

          // shows spinner while searching
          if (isSearching)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )

          // shows clear button if text exists
          else if (hasSearchText)
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white70,
                size: 18,
              ),
              onPressed: onClearSearch,
            )

          // keeps spacing balanced if nothing is shown
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  final bool showSuggestions;
  final List<String> suggestionNames;
  final Future<void> Function(int index) onSuggestionTap;

  const _SuggestionsCard({
    required this.showSuggestions,
    required this.suggestionNames,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    // hide completely if there are no suggestions to show
    if (!showSuggestions) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: suggestionNames.asMap().entries.map((entry) {
          final index = entry.key;
          final name = entry.value;

          return Column(
            children: [
              // single suggestion row
              ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white70,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => onSuggestionTap(index),
              ),

              // divider between suggestions
              if (index != suggestionNames.length - 1)
                const Divider(
                  height: 1,
                  color: Colors.white10,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}