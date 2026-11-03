import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/api_config.dart';
import 'lesson_page.dart';

class FavoritesPage extends StatefulWidget {
  final String username;

  const FavoritesPage({super.key, required this.username});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<String> favorites = [];
  List<String> _filteredFavorites = [];
  final TextEditingController _searchController = TextEditingController();

  Future<void> fetchFavorites() async {
    final uri = Uri.parse(ApiConfig.buildUrl('/favorites/list'));
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"username": widget.username}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        favorites = List<String>.from(data["favorites"]);
        _filteredFavorites = List.from(favorites);
      });
    } else {
      debugPrint("Error fetching favorites: ${response.body}");
    }
  }

  void _searchFavorites() {
    String query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFavorites = List.from(favorites);
      } else {
        _filteredFavorites = favorites
            .where((fav) => fav.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFavorites();
  }

  @override
  void initState() {
    super.initState();
    fetchFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Favorites"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              margin: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 15),
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color.fromARGB(80, 176, 176, 176),
                    blurRadius: 10,
                    spreadRadius: 0.0,
                  )
                ],
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _searchFavorites(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(15),
                  hintText: 'Search favorites...',
                  hintStyle: const TextStyle(
                    color: Color.fromARGB(255, 176, 176, 176),
                    fontSize: 14,
                  ),
                  prefixIcon: InkWell(
                    onTap: _searchFavorites,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset('assets/icons/search.svg',
                          width: 10, height: 10),
                    ),
                  ),
                  suffixIcon: InkWell(
                    onTap: _clearSearch,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset('assets/icons/remove.svg',
                          width: 10, height: 10),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Favorites list
            Expanded(
              child: _filteredFavorites.isEmpty
                  ? const Center(child: Text("No favorites yet"))
                  : ListView.builder(
                      itemCount: _filteredFavorites.length,
                      itemBuilder: (context, index) {
                        final fav = _filteredFavorites[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LessonPage(
                                  lessonName: fav,
                                  username: widget.username,
                                  token: "", // ⚠️ you should pass token here
                                  email: "", // ⚠️ also pass email if needed
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                            child: Row(
                              children: [
                                SvgPicture.asset('assets/icons/course.svg',
                                    width: 30, height: 30),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    fav,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
