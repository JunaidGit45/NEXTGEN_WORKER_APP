import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ProfileScreen = WorkerProfileScreen;

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _workerUsername = "MALIK10";
  String _workerFullName = "Worker";
  String _workerPhone = "-";

  double _rating = 5.0;
  int _totalReviews = 0;
  String _ratingTag = "Skilled Builder";
  String _ratingComment = "Awaiting feedback from director";

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkerProfile();
  }

  Future<void> _loadWorkerProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('logged_worker_username') ??
          prefs.getString('logged_operator_username') ??
          'MALIK10';

      _workerUsername = savedUser.trim().toUpperCase();

      final data = await _supabase
          .from('workers')
          .select()
          .eq('username', _workerUsername)
          .maybeSingle();

      if (data != null) {
        _workerFullName = (data['full_name'] ?? _workerUsername).toString();
        _workerPhone = (data['phone'] ?? '-').toString();
        _rating = (data['rating'] as num?)?.toDouble() ?? 5.0;
        _totalReviews = (data['total_reviews'] as num?)?.toInt() ?? 0;
        _ratingTag = (data['rating_tag'] ?? 'Skilled Builder').toString();
        _ratingComment = (data['rating_comment'] ?? 'Consistent performance').toString();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPositive = _rating >= 4.0;
    final Color badgeColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: const Color(0xFF07121A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2232),
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Worker Profile & Performance",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8)),
            onPressed: _loadWorkerProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE88226)))
          : RefreshIndicator(
              color: const Color(0xFFE88226),
              backgroundColor: const Color(0xFF0C2232),
              onRefresh: _loadWorkerProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C2232),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF193B54)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0284C7)),
                          ),
                          child: const Icon(Icons.engineering_rounded, color: Color(0xFF38BDF8), size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _workerFullName,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Worker ID: $_workerUsername",
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Phone: $_workerPhone",
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1F2F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: badgeColor.withOpacity(0.5), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Director Performance Rating",
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF071420),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFEF4444)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$_rating / 5.0",
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: List.generate(5, (index) {
                            final int starVal = index + 1;
                            final bool filled = starVal <= _rating.round();

                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: filled ? const Color(0xFFEF4444) : const Color(0xFF475569),
                                size: 26,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text("Factory Feedback: ", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: badgeColor),
                              ),
                              child: Text(
                                _ratingTag.toUpperCase(),
                                style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF071420),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF193B54)),
                          ),
                          child: Text(
                            "\"$_ratingComment\"",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Based on $_totalReviews Director Review(s)",
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}