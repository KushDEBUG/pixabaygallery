import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // For environment variables

Future<void> main() async {
  await dotenv.load(fileName: ".env"); // Load environment variables
  runApp(const PixabayGalleryApp());
}

class PixabayGalleryApp extends StatelessWidget {
  const PixabayGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixabay Gallery',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GalleryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ImageItem {
  final String imageUrl;
  final int likes;
  final int views;

  ImageItem({required this.imageUrl, required this.likes, required this.views});

  factory ImageItem.fromJson(Map<String, dynamic> json) {
    return ImageItem(
      imageUrl: json['webformatURL'],
      likes: json['likes'],
      views: json['views'],
    );
  }
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _GalleryPageState createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final List<ImageItem> _images = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _perPage = 20;
  final ScrollController _scrollController = ScrollController();

  final String _apiKey = dotenv.env['46323742-89a1de7d1654e8ebd03915d74'] ?? '';

  @override
  void initState() {
    super.initState();
    _fetchImages();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoading &&
          _hasMore) {
        _fetchImages();
      }
    });
  }

  Future<void> _fetchImages() async {
    if (_apiKey.isEmpty) {
      _showErrorSnackBar('API Key is missing.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String url =
        'https://pixabay.com/api/?key=$_apiKey&image_type=photo&pretty=true&page=$_currentPage&per_page=$_perPage';

    try {
      final response = await http.get(Uri.parse(url));

      if (kDebugMode) {
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List hits = data['hits'];

        if (hits.isNotEmpty) {
          setState(() {
            _currentPage++;
            _images
                .addAll(hits.map((json) => ImageItem.fromJson(json)).toList());
            if (hits.length < _perPage) {
              _hasMore = false;
            }
          });
        } else {
          setState(() {
            _hasMore = false;
          });
        }
      } else {
        _showErrorSnackBar('Error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    final context = this.context;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Determine the number of columns based on screen width
  int _calculateCrossAxisCount(double width) {
    if (width >= 1600) {
      return 8;
    } else if (width >= 1400) {
      return 7;
    } else if (width >= 1200) {
      return 6;
    } else if (width >= 992) {
      return 5;
    } else if (width >= 768) {
      return 4;
    } else if (width >= 576) {
      return 3;
    } else {
      return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = _calculateCrossAxisCount(screenWidth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pixabay Gallery'),
      ),
      body: _images.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _images.clear();
                  _currentPage = 1;
                  _hasMore = true;
                });
                await _fetchImages();
              },
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 0.7,
                ),
                itemCount: _images.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _images.length) {
                    // Display a loading indicator at the end
                    return const Center(child: CircularProgressIndicator());
                  }

                  final image = _images[index];
                  return ImageCard(image: image);
                },
              ),
            ),
    );
  }
}

class ImageCard extends StatelessWidget {
  final ImageItem image;

  const ImageCard({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: CachedNetworkImage(
              imageUrl: image.imageUrl,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              ),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 4.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, size: 16.0, color: Colors.red),
                const SizedBox(width: 4.0),
                Text('${image.likes}'),
              ],
            ),
            Row(
              children: [
                Icon(Icons.remove_red_eye, size: 16.0, color: Colors.grey[700]),
                const SizedBox(width: 4.0),
                Text('${image.views}'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
