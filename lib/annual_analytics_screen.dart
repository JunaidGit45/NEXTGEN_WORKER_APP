import 'dart:math';
import 'package:flutter/material.dart';
import 'custom_drawer.dart';

class AnnualAnalyticsScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialJobs;

  const AnnualAnalyticsScreen({super.key, this.initialJobs});

  @override
  State<AnnualAnalyticsScreen> createState() => _AnnualAnalyticsScreenState();
}

class _AnnualAnalyticsScreenState extends State<AnnualAnalyticsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _workerList = [];
  String _selectedYear = '2026';

  final List<String> _trackedYears = ['2024', '2025', '2026', '2027'];

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _workerList = [
          {'name': 'Ramesh Kumar', 'status': 'RUNNING', 'rating': 4.5, 'tasks_done': 24, 'efficiency': 94},
          {'name': 'Mohd Imran', 'status': 'TESTING', 'rating': 4.8, 'tasks_done': 31, 'efficiency': 98},
          {'name': 'Suresh Patil', 'status': 'PENDING', 'rating': 3.5, 'tasks_done': 18, 'efficiency': 82},
          {'name': 'Junaid Ansari', 'status': 'READY', 'rating': 5.0, 'tasks_done': 42, 'efficiency': 99},
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final Color screenBg = isDark ? const Color(0xFF07121A) : const Color(0xFFF1F5F9);
        final Color cardBg = isDark ? const Color(0xFF0C2232) : Colors.white;
        final Color borderColor = isDark ? const Color(0xFF1E3E5A) : const Color(0xFFCBD5E1);
        final Color textMain = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        double totalRating = _workerList.fold(0.0, (s, w) => s + (w['rating'] as num).toDouble());
        double avgTeamRating = _workerList.isNotEmpty ? (totalRating / _workerList.length) : 0.0;

        return Scaffold(
          backgroundColor: screenBg,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF0C2232) : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: textMain),
            title: Text("Worker Performance Analytics", style: TextStyle(color: textMain, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE88226)))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Row(
                      children: _trackedYears.map((yr) {
                        final isSelected = yr == _selectedYear;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedYear = yr),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFE88226) : cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? const Color(0xFFE88226) : borderColor),
                              ),
                              alignment: Alignment.center,
                              child: Text("FY $yr", style: TextStyle(color: isSelected ? Colors.white : textSub, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // SUMMARY CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Team Average Rating", style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 28),
                                  const SizedBox(width: 4),
                                  Text("${avgTeamRating.toStringAsFixed(1)} / 5.0", style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 22, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Text("TOP TIER", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // WORKER SCORE CARDS
                    Text("Top Operator Ratings", style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ..._workerList.map((w) {
                      final double r = (w['rating'] as num).toDouble();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF0284C7).withOpacity(0.2),
                              child: Text(w['name'][0], style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w['name'], style: TextStyle(color: textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text("Tasks Completed: ${w['tasks_done']} • Efficiency: ${w['efficiency']}%", style: TextStyle(color: textSub, fontSize: 10)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                  const SizedBox(width: 3),
                                  Text("$r", style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        );
      },
    );
  }
}