import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'business_dashboard_screen.dart';
import 'business_venue_loader.dart';

// back button
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2E2E2E),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const BusinessDashboardScreen(),
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusinessEditVenueScreen extends StatefulWidget {
  const BusinessEditVenueScreen({super.key});

  @override
  State<BusinessEditVenueScreen> createState() =>
      _BusinessEditVenueScreenState();
}

class _BusinessEditVenueScreenState extends State<BusinessEditVenueScreen> {
  final TextEditingController _venueNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _openingHoursController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _venueDocId;
  bool _isLoading = true;
  bool _isSaving = false;

  bool _glutenFree = false;
  bool _vegetarian = false;
  bool _dairyFree = false;
  bool _vegan = false;

  @override
  void initState() {
    super.initState();
    _loadVenueData();
  }

  @override
  void dispose() {
    _venueNameController.dispose();
    _descriptionController.dispose();
    _openingHoursController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadVenueData() async {
    final result = await BusinessVenueLoader.loadManagedVenue();

    if (!mounted) return;

    if (result.hasError) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!)),
      );
      return;
    }

    final data = result.venueData ?? <String, dynamic>{};
    final tags = Map<String, dynamic>.from(data['tags'] ?? {});
    final notesRaw = data['notes'];

    // first note shows as description
    String descriptionText = '';
    if (notesRaw is List && notesRaw.isNotEmpty) {
      descriptionText = notesRaw.first?.toString().trim() ?? '';
    } else {
      descriptionText = (data['description'] ?? '').toString();
    }

    // fill the form with the current venue data
    _venueDocId = result.venueId;
    _venueNameController.text = (data['name'] ?? '').toString();
    _descriptionController.text = descriptionText;
    _openingHoursController.text = (data['openingHours'] ?? '').toString();
    _phoneController.text = (data['phone'] ?? '').toString();

    _glutenFree = tags['glutenFree'] == true;
    _vegetarian = tags['vegetarian'] == true;
    _dairyFree = tags['dairyFree'] == true;
    _vegan = tags['vegan'] == true;

    setState(() => _isLoading = false);
  }

  Future<void> _saveChanges() async {
    if (_isSaving || _venueDocId == null) return;

    final description = _descriptionController.text.trim();
    final openingHours = _openingHoursController.text.trim();
    final phone = _phoneController.text.trim();

    // save description into notes
    final List<String> notes = description.isEmpty ? [] : [description];

    // tags used for filters and search
    final Map<String, bool> tags = {
      'glutenFree': _glutenFree,
      'vegetarian': _vegetarian,
      'dairyFree': _dairyFree,
      'vegan': _vegan,
    };

    // text version of tags for easier matching in the app
    final List<String> tagList = [];
    if (_glutenFree) tagList.add('gluten free');
    if (_vegetarian) tagList.add('vegetarian');
    if (_dairyFree) tagList.add('dairy free');
    if (_vegan) tagList.add('vegan');

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('venues').doc(_venueDocId).update({
        'description': description,
        'notes': notes,
        'openingHours': openingHours,
        'phone': phone,
        'tags': tags,
        'tagList': tagList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue details updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save changes: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openLargeEditor({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required int minLines,
    required int maxLines,
  }) async {
    final tempController = TextEditingController(text: controller.text);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 14),

                // bigger editor for longer text
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: tempController,
                    minLines: minLines,
                    maxLines: maxLines,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.45,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 17,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // copy the edited text back into the main field
                          setState(() {
                            controller.text = tempController.text;
                          });
                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111111),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    tempController.dispose();
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white70,
          fontSize: 18,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 18),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildExpandableField({
    required String value,
    required String hintText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value.trim().isEmpty ? hintText : value.trim(),
                  style: TextStyle(
                    color: value.trim().isEmpty ? Colors.white38 : Colors.white,
                    fontSize: 18,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.open_in_full_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            side: const BorderSide(color: Colors.white, width: 2),
            checkColor: Colors.black,
            activeColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // back button
            const _BackButton(),

            const SizedBox(height: 22),

            const Center(
              child: Text(
                'Edit Venue Information',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 32),

            _buildLabel('Venue Name'),
            const SizedBox(height: 10),

            // locked field
            _buildInputField(
              controller: _venueNameController,
              hintText: 'Venue Name',
              enabled: false,
              suffixIcon: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.lock, color: Colors.white70, size: 20),
              ),
            ),

            const SizedBox(height: 18),

            _buildLabel('Description'),
            const SizedBox(height: 10),

            // opens larger editor
            _buildExpandableField(
              value: _descriptionController.text,
              hintText: 'Description',
              onTap: () {
                _openLargeEditor(
                  title: 'Description',
                  controller: _descriptionController,
                  hintText: 'Description',
                  minLines: 6,
                  maxLines: 8,
                );
              },
            ),

            const SizedBox(height: 18),

            _buildLabel('Opening Hours'),
            const SizedBox(height: 10),

            // opens larger editor
            _buildExpandableField(
              value: _openingHoursController.text,
              hintText: 'Opening Hours',
              onTap: () {
                _openLargeEditor(
                  title: 'Opening Hours',
                  controller: _openingHoursController,
                  hintText: 'Opening Hours',
                  minLines: 4,
                  maxLines: 6,
                );
              },
            ),

            const SizedBox(height: 18),

            _buildLabel('Contact Number'),
            const SizedBox(height: 10),
            _buildInputField(
              controller: _phoneController,
              hintText: 'Contact Number',
            ),

            const SizedBox(height: 18),

            _buildLabel('Allergen Tags'),
            const SizedBox(height: 12),

            _buildTagCheckbox(
              label: 'Gluten free',
              value: _glutenFree,
              onChanged: (v) => setState(() => _glutenFree = v ?? false),
            ),
            const SizedBox(height: 8),
            _buildTagCheckbox(
              label: 'Vegetarian',
              value: _vegetarian,
              onChanged: (v) => setState(() => _vegetarian = v ?? false),
            ),
            const SizedBox(height: 8),
            _buildTagCheckbox(
              label: 'Dairy free',
              value: _dairyFree,
              onChanged: (v) => setState(() => _dairyFree = v ?? false),
            ),
            const SizedBox(height: 8),
            _buildTagCheckbox(
              label: 'Vegan',
              value: _vegan,
              onChanged: (v) => setState(() => _vegan = v ?? false),
            ),

            const SizedBox(height: 42),

            Center(
              child: SizedBox(
                width: 230,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF111111),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            const Center(
              child: Text(
                'Changes made may take a few minutes\nto update',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF222222),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : _buildBody(),
      ),
    );
  }
}