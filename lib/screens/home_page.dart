import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app_tp2/config/api_config.dart';
import 'package:app_tp2/screens/add_show_page.dart';
import 'package:app_tp2/screens/profile_page.dart';
import 'package:app_tp2/screens/update_show_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<dynamic> movies = [];
  List<dynamic> anime = [];
  List<dynamic> series = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  final StreamController<void> _refreshController = StreamController<void>.broadcast();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _refreshController.close();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await fetchShows();
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.toString();
      });
      _showErrorSnackbar('Failed to load shows: $e');
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> fetchShows() async {
    setState(() => isLoading = true);

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/shows'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> allShows = jsonDecode(response.body);
        _organizeShows(allShows);
      } else if (response.statusCode == 401) {
        // Token invalide ou expiré
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Server responded with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch shows: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        _refreshController.add(null);
      }
    }
  }

  void _organizeShows(List<dynamic> allShows) {
    setState(() {
      movies = allShows.where((show) => show['category'] == 'movie').toList();
      anime = allShows.where((show) => show['category'] == 'anime').toList();
      series = allShows.where((show) => show['category'] == 'serie').toList();
      hasError = false;
    });
  }

  Future<void> deleteShow(int id) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/shows/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          _showSuccessSnackbar('Show deleted successfully');
          await fetchShows();
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to delete show: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to delete show: $e');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Show"),
        content: const Text("Are you sure you want to delete this show?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await deleteShow(id);
    }
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return ShowGrid(
          shows: movies,
          onDelete: _confirmDelete,
          refreshStream: _refreshController.stream,
        );
      case 1:
        return ShowGrid(
          shows: anime,
          onDelete: _confirmDelete,
          refreshStream: _refreshController.stream,
        );
      case 2:
        return ShowGrid(
          shows: series,
          onDelete: _confirmDelete,
          refreshStream: _refreshController.stream,
        );
      default:
        return const Center(child: Text("Unknown Page"));
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Show App"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildContent(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: "Movies"),
          BottomNavigationBarItem(icon: Icon(Icons.animation), label: "Anime"),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: "Series"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Text(
              "Menu",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text("Add Show"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddShowPage()),
              ).then((_) => _loadData());
            },
          ),
          // Ajoutez ce bouton de déconnexion
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }
}

class ShowGrid extends StatelessWidget {
  final List<dynamic> shows;
  final Function(int) onDelete;
  final Stream<void> refreshStream;

  const ShowGrid({
    super.key,
    required this.shows,
    required this.onDelete,
    required this.refreshStream,
  });

  void _navigateToUpdate(BuildContext context, dynamic show) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateShowPage(show: show),
      ),
    ).then((updated) {
      if (updated == true) {
        // Le rafraîchissement est maintenant géré par le Stream
        final homeState = context.findAncestorStateOfType<_HomePageState>();
        homeState?._loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: refreshStream,
      builder: (context, snapshot) {
        if (shows.isEmpty) {
          return const Center(
            child: Text(
              "No Shows Available",
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.7,
          ),
          itemCount: shows.length,
          itemBuilder: (context, index) {
            final show = shows[index];
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  // Handle show details
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                        child: show['image'] != null && show['image'].isNotEmpty
                            ? Image.network(
                          ApiConfig.baseUrl + show['image'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image)),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        )
                            : const Center(child: Icon(Icons.image)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            show['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            show['description'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                              label: const Text(
                                "Edit",
                                style: TextStyle(fontSize: 14, color: Colors.blue),
                              ),
                              onPressed: () => _navigateToUpdate(context, show),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: Colors.grey,
                          ),
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              label: const Text(
                                "Delete",
                                style: TextStyle(fontSize: 14, color: Colors.red),
                              ),
                              onPressed: () => onDelete(show['id']),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}