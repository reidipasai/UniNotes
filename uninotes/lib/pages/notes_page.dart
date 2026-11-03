import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class NotesPage extends StatefulWidget {
  final String channelName;
  final String username;
  final String token;

  const NotesPage({
    super.key,
    required this.channelName,
    required this.username,
    required this.token,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Map<String, dynamic>> _notesList = [];
  bool _loading = true;
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  List<XFile> _capturedImages = [];
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _fetchNotes();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _fetchNotes() async {
    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.buildUrl('/files/MediaFiles/channel')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'channel': widget.channelName,
          'file_type': 'PDF',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _notesList = List<Map<String, dynamic>>.from(data['files']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showError('Failed to load notes');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error loading notes: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _startCapture() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showError('Camera permission denied');
      return;
    }

    if (_cameras.isEmpty) {
      _showError('No cameras available');
      return;
    }

    setState(() => _isCapturing = true);
    _capturedImages.clear();

    _controller = CameraController(_cameras[0], ResolutionPreset.high);
    await _controller!.initialize();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraCaptureScreen(
            controller: _controller!,
            onImagesCapture: (images) {
              setState(() {
                _capturedImages = images;
                _isCapturing = false;
              });
              if (images.isNotEmpty) {
                _processCapturedImages();
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _processCapturedImages() async {
    if (_capturedImages.isEmpty) return;

    try {
      _showLoadingDialog();

      final pdf = pw.Document();

      for (final imageFile in _capturedImages) {
        final imageBytes = await imageFile.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_notes.pdf');
      await tempFile.writeAsBytes(await pdf.save());

      await _uploadPDF(tempFile);

      await tempFile.delete();

      Navigator.of(context).pop();
      _showSuccess('Notes uploaded successfully!');
      _fetchNotes();

    } catch (e) {
      Navigator.of(context).pop();
      _showError('Error processing images: $e');
    }
  }

  Future<void> _uploadPDF(File pdfFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.buildUrl('/files/upload')),
      );

      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['user'] = widget.username;
      request.fields['channel'] = widget.channelName;
      request.fields['file_type'] = 'PDF';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          pdfFile.path,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      final response = await request.send();

      if (response.statusCode != 201) {
        throw Exception('Failed to upload PDF');
      }
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> note) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.buildUrl('/files/MediaFiles/toggle-like')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'channel': widget.channelName,
          'file_no': note['file_no'],
          'file_type': 'PDF',
          'username': widget.username,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          note['likes'] = data['likes'];
          note['liked'] = data['liked'];
        });
      } else {
        _showError('Failed to update like');
      }
    } catch (e) {
      _showError('Error updating like: $e');
    }
  }

  Future<void> _downloadPDF(Map<String, dynamic> note) async {
    try {
      final filepath = note['filepath'] as String?;
      if (filepath == null || filepath.isEmpty) {
        _showError('File path not available');
        return;
      }

      final downloadUrl = '${ApiConfig.baseUrl}/$filepath';
      print('Attempting to download PDF from: $downloadUrl');
      
      final uri = Uri.parse(downloadUrl);
      
      try {
        final canLaunch = await canLaunchUrl(uri);
        print('Can launch URL: $canLaunch');
        
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _showSuccess('Opening PDF...');
        } else {
          await launchUrl(uri);
          _showSuccess('Opening PDF...');
        }
      } catch (e) {
        print('Launch failed: $e');
        _showError('Could not open PDF: $downloadUrl\nError: $e');
      }
    } catch (e) {
      _showError('Error downloading PDF: $e');
      print('Download error: $e');
    }
  }



  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Processing and uploading...'),
          ],
        ),
      ),
    );
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
          '${widget.channelName} - Notes',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notesList.isEmpty
              ? const Center(
                  child: Text(
                    'No notes uploaded yet.\nTap the + button to add your first notes!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notesList.length,
                  itemBuilder: (context, index) {
                    final note = _notesList[index];
                    return _buildNoteCard(note);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCapturing ? null : _startCapture,
        backgroundColor: Colors.black,
        child: _isCapturing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    bool isLiked = note['liked'] ?? 
      (note['liked_by'] != null && note['liked_by'].contains(widget.username));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note['filename'] ?? 'Unknown file',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By: ${note['user']}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uploaded: ${note['uploaded_at']}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 👇 Likes Counter + Toggle
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _toggleLike(note),
                        icon: isLiked
                            ? const Icon(Icons.thumb_up, color: Colors.black)   
                            : const Icon(Icons.thumb_up_outlined, color: Colors.black), 
                      ),
                      Text(
                        '${note['likes'] ?? 0} Likes',
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _downloadPDF(note),
              icon: const Icon(Icons.download, color: Colors.black),
              tooltip: 'Download PDF',
            ),
          ],
        ),
      ),
    );
  }
}

class CameraCaptureScreen extends StatefulWidget {
  final CameraController controller;
  final Function(List<XFile>) onImagesCapture;

  const CameraCaptureScreen({
    super.key,
    required this.controller,
    required this.onImagesCapture,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  List<XFile> capturedImages = [];
  bool isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Capture Notes (${capturedImages.length} photos)',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (capturedImages.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onImagesCapture(capturedImages);
              },
              child: const Text(
                'DONE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(widget.controller),
          ),
          // Capture button
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery preview (show last captured image)
                if (capturedImages.isNotEmpty)
                  GestureDetector(
                    onTap: _showCapturedImages,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 60),
                
                // Capture button
                GestureDetector(
                  onTap: isCapturing ? null : _captureImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isCapturing ? Colors.grey : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 4),
                    ),
                    child: isCapturing
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.camera_alt, size: 40),
                  ),
                ),
                
                // Switch camera button
                GestureDetector(
                  onTap: _switchCamera,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage() async {
    if (isCapturing) return;

    setState(() => isCapturing = true);

    try {
      final image = await widget.controller.takePicture();
      setState(() {
        capturedImages.add(image);
        isCapturing = false;
      });
    } catch (e) {
      setState(() => isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }

  void _switchCamera() {
    // TODO: Implement camera switching if multiple cameras are available
  }

  void _showCapturedImages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Captured Images (${capturedImages.length})'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: capturedImages.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    Image.file(
                      File(capturedImages[index].path),
                      width: 100,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            capturedImages.removeAt(index);
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
