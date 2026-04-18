import 'package:flutter/material.dart';

import '../models/diet_tag.dart';
import '../services/user_preferences_service.dart';
import 'home_screen.dart';
import 'widgets/auth_components.dart';

// diet preferences screen
class DietPreferencesScreen extends StatefulWidget {
  const DietPreferencesScreen({super.key});

  @override
  State<DietPreferencesScreen> createState() => _DietPreferencesScreenState();
}

class _DietPreferencesScreenState extends State<DietPreferencesScreen> {
  final Set<DietTag> _selectedTags = <DietTag>{};
  bool _saving = false;
  String? _error;

  void _toggleTag(DietTag tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }

      _error = null;
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedTags.isEmpty) {
      setState(() {
        _error = 'Please choose at least one filter';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await UserPreferencesService.saveDietPreferences(_selectedTags);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'could not save your preferences';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        children: [
          const SizedBox(height: 10),

          // app title
          const Text(
            'oofy',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Choose Your Filters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          const Text(
            'Select one or more dietary filters to personalise your map',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          // filter options
          Expanded(
            child: ListView(
              children: DietTag.values.map((tag) {
                final selected = _selectedTags.contains(tag);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _toggleTag(tag),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? Colors.white24
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              border: Border.all(
                                color: Colors.white70,
                                width: 1.2,
                              ),
                            ),
                            child: selected
                                ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.black,
                            )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            DietTagHelper.labels[tag]!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFFB4B4),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // continue button
          PrimaryPillButton(
            text: 'continue',
            loading: _saving,
            onPressed: _saveAndContinue,
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }
}