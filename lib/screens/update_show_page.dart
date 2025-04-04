import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_tp2/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UpdateShowPage extends StatefulWidget {
  final dynamic show;

  const UpdateShowPage({super.key, required this.show});

  @override
  State<UpdateShowPage> createState() => _UpdateShowPageState();
}

class _UpdateShowPageState extends State<UpdateShowPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _category;
  File? _imageFile;
  String? _currentImageUrl;
  bool _isLoading = false;
  bool _removeImage = false;

  final List<String> _categories = ['movie', 'anime', 'serie'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.show['title']);
    _descriptionController = TextEditingController(text: widget.show['description']);
    _category = widget.show['category'];
    _currentImageUrl = widget.show['image'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _currentImageUrl = null;
        _removeImage = false;
      });
    }
  }

  Future<void> _removeCurrentImage() async {
    setState(() {
      _imageFile = null;
      _currentImageUrl = null;
      _removeImage = true;
    });
  }

  Future<String?> _uploadImage(String token) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('image', _imageFile!.path),
      );

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return jsonDecode(responseData)['imagePath'];
      }
      return null;
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _updateShow() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Récupération du token
      final token = await _getToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
        return;
      }

      // 2. Upload de la nouvelle image si nécessaire
      String? imagePath;
      if (_imageFile != null) {
        imagePath = await _uploadImage(token); // Passez le token à _uploadImage
      }

      // 3. Préparation des données
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        if (imagePath != null) 'image': imagePath,
        if (_removeImage) 'image': '', // Pour suppression d'image
      };

      debugPrint('Sending update for show ${widget.show['id']}: ${jsonEncode(data)}');

      // 4. Envoi de la requête PUT avec authentification
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/shows/${widget.show['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      // 5. Gestion des réponses
      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Show updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
      else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
      else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['errors'] is List
            ? errorData['errors'].join('\n')
            : errorData['message'] ?? 'Failed to update show';
        throw Exception(errorMessage);
      }
    }
    catch (e) {
      debugPrint('Update error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
    finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Show'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _updateShow,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_currentImageUrl != null &&
                          _currentImageUrl!.isNotEmpty &&
                          !_removeImage)
                          ? NetworkImage('${ApiConfig.baseUrl}$_currentImageUrl')
                          : null,
                      child: (_imageFile == null &&
                          (_currentImageUrl == null ||
                              _currentImageUrl!.isEmpty ||
                              _removeImage))
                          ? const Icon(Icons.add_a_photo, size: 40)
                          : null,
                    ),
                  ),
                  if ((_currentImageUrl != null &&
                      _currentImageUrl!.isNotEmpty &&
                      !_removeImage) ||
                      _imageFile != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _removeCurrentImage,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title*',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description*',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category*',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category[0].toUpperCase() + category.substring(1)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
                validator: (value) {
                  if (value == null || !_categories.contains(value)) {
                    return 'Please select a valid category';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}