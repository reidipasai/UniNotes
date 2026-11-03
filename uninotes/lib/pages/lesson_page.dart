import 'package:flutter/material.dart';
import 'ChatPage.dart';
import 'notes_page.dart';
import 'audio_notes_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class LessonPage extends StatefulWidget {
  final String lessonName;
  final String username;
  final String token;
  final String email;

  const LessonPage({
    super.key,
    required this.lessonName,
    required this.username,
    required this.token,
    required this.email,
  });

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite(); // ✅ sync with backend when page opens
  }

  Future<void> _checkIfFavorite() async {
    final uri = Uri.parse(ApiConfig.buildUrl('/favorites/list'));
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"username": widget.username}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<String> favorites = List<String>.from(data["favorites"]);
      setState(() {
        isFavorite = favorites.contains(widget.lessonName);
      });
    } else {
      debugPrint("Error fetching favorites: ${response.body}");
    }
  }

  Future<void> _toggleFavorite() async {
    final uri = Uri.parse(ApiConfig.buildUrl('/favorites/toggle'));
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "username": widget.username,
        "lesson_name": widget.lessonName,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        isFavorite = !isFavorite;
      });
    } else {
      debugPrint("Error toggling favorite: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.lessonName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // ❤️ Favorite icon (no circle background)
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: Colors.black,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Placeholder image
            Container(
              margin: const EdgeInsets.all(20),
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 50, color: Colors.black54),
              ),
            ),

            const SizedBox(height: 20),

            _buildButton(context, 'Chat'),
            const SizedBox(height: 15),
            _buildButton(context, 'Record Lesson'),
            const SizedBox(height: 15),
            _buildButton(context, 'Notes'),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () {
          if (text == 'Chat') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  channelName:
                      widget.lessonName.toLowerCase().replaceAll(' ', '_'),
                  username: widget.username,
                  token: widget.token,
                ),
              ),
            );
          } else if (text == 'Notes') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotesPage(
                  channelName:
                      widget.lessonName.toLowerCase().replaceAll(' ', '_'),
                  username: widget.username,
                  token: widget.token,
                ),
              ),
            );
          } else if (text == 'Record Lesson') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AudioNotesPage(
                  channelName:
                      widget.lessonName.toLowerCase().replaceAll(' ', '_'),
                  username: widget.username,
                  token: widget.token,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
