import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'semester_detail_page.dart';

class HomePage extends StatefulWidget {
  final String token;
  final String username;
  final String email;
  
  const HomePage({
    super.key, 
    required this.token,
    required this.username,
    required this.email,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _allLectures = [
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Flows',
    'Others',
  ];
  List<String> _filteredLectures = [];

  @override
  void initState() {
    super.initState();
    _filteredLectures = List.from(_allLectures);
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
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            margin: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 15),
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Color.fromARGB(80, 103, 103, 103),
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
                hintText: 'Search semesters...',
                hintStyle: const TextStyle(
                  color: Color.fromARGB(255, 176, 176, 176),
                  fontSize: 14,
                ),
                prefixIcon: InkWell(
                  onTap: _searchLectures,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SvgPicture.asset('assets/icons/search.svg', width: 10, height: 10),
                  ),
                ),
                suffixIcon: InkWell(
                  onTap: _clearSearch,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SvgPicture.asset('assets/icons/remove.svg', width: 10, height: 10),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Semesters",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 10),

          // Courses list
          Expanded(
            child: ListView.builder(
              itemCount: _filteredLectures.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    if (_filteredLectures[index] == 'Semester 1') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SemesterDetailPage(
                            semesterName: 'Semester 1',
                            token: widget.token,
                            username: widget.username,
                            email: widget.email,
                          ),
                        ),
                      );
                   }
                 },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: Row(
                      children: [
                        SvgPicture.asset('assets/icons/course.svg', width: 30, height: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            _filteredLectures[index],
                            style: const TextStyle(fontSize: 16),
                         ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
