import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.buildUrl('/leaderboard/leaderboard')),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _leaderboard = List<Map<String, dynamic>>.from(data['leaderboard']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showError('Failed to load leaderboard');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Widget _buildRankIcon(int index) {
    if (index == 0) {
      return SvgPicture.asset("assets/icons/1st.svg", width: 36, height: 36);
    } else if (index == 1) {
      return SvgPicture.asset("assets/icons/2nd.svg", width: 36, height: 36);
    } else if (index == 2) {
      return SvgPicture.asset("assets/icons/3rd.svg", width: 36, height: 36);
    } else {
      return Text(
        "${index + 1}",
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Leaderboard",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _leaderboard.isEmpty
                ? const Center(child: Text("No contributions yet"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leaderboard.length,
                    itemBuilder: (context, index) {
                      final entry = _leaderboard[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: _buildRankIcon(index),
                          title: Text(entry['username']),
                          subtitle: Text(entry['email']),
                          trailing: Text(
                            "${entry['likes']} Likes",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
