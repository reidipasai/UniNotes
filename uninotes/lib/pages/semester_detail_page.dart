import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'lesson_page.dart';

class SemesterDetailPage extends StatefulWidget {
  final String semesterName;
  final String token;
  final String username;
  final String email;

  const SemesterDetailPage({
    super.key,
    required this.semesterName,
    required this.token,
    required this.username,
    required this.email,
  });

  @override
  State<SemesterDetailPage> createState() => _SemesterDetailPageState();
}

class _SemesterDetailPageState extends State<SemesterDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _allLectures = [
    'Mathematics 1',
    'History',
    'Physics 1',
    'Linear Algebra',
    'ProgIntro',
    'Others',
  ];
  List<String> _filteredLectures = [];

  @override
  void initState() {
    super.initState();
    _filteredLectures = List.from(_allLectures);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchLectures() {
    String query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLectures = List.from(_allLectures);
      } else {
        _filteredLectures = _allLectures
            .where((lecture) => lecture.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchLectures();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          widget.semesterName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              margin:
                  const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 15),
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
                onSubmitted: (_) => _searchLectures(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(15),
                  hintText: 'Search lectures...',
                  hintStyle: const TextStyle(
                    color: Color.fromARGB(255, 176, 176, 176),
                    fontSize: 14,
                  ),
                  prefixIcon: InkWell(
                    onTap: _searchLectures,
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

            // Lectures list
            Expanded(
              child: _filteredLectures.isEmpty
                  ? const Center(child: Text('No lectures found'))
                  : ListView.builder(
                      itemCount: _filteredLectures.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LessonPage(
                                  lessonName: _filteredLectures[index],
                                  username: widget.username,
                                  token: widget.token,
                                  email: widget.email,
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
                                    _filteredLectures[index],
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
