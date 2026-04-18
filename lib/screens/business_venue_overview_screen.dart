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

// venue overview screen
class BusinessVenueOverviewScreen extends StatefulWidget {
  const BusinessVenueOverviewScreen({super.key});

  @override
  State<BusinessVenueOverviewScreen> createState() =>
      _BusinessVenueOverviewScreenState();
}

class _BusinessVenueOverviewScreenState
    extends State<BusinessVenueOverviewScreen> {
  String _venueName = '';
  String _address = '';
  String _notes = '';
  String _openingHours = '';
  String _phone = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVenueData();
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
    final notesRaw = data['notes'];

    // join notes into one block
    String notesText = '';
    if (notesRaw is List) {
      final cleanedNotes = notesRaw
          .map((note) => note?.toString().trim() ?? '')
          .where((note) => note.isNotEmpty)
          .toList();

      notesText = cleanedNotes.join('\n\n');
    } else {
      notesText = (data['description'] ?? '').toString();
    }

    setState(() {
      _venueName = (data['name'] ?? '').toString();
      _address = (data['address'] ?? '').toString();
      _notes = notesText;
      _openingHours = (data['openingHours'] ?? '').toString();
      _phone = (data['phone'] ?? '').toString();
      _isLoading = false;
    });
  }

  Widget _buildInfoCard({required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value.isEmpty ? 'No data available' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // back button
            const _BackButton(),

            const SizedBox(height: 22),

            const Center(
              child: Text(
                'Venue Overview',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 28),

            _buildInfoCard(label: 'Venue', value: _venueName),
            const SizedBox(height: 10),
            _buildInfoCard(label: 'Address', value: _address),
            const SizedBox(height: 10),
            _buildInfoCard(label: 'Notes', value: _notes),
            const SizedBox(height: 10),
            _buildInfoCard(label: 'Opening Hours', value: _openingHours),
            const SizedBox(height: 10),
            _buildInfoCard(label: 'Contact Number', value: _phone),
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