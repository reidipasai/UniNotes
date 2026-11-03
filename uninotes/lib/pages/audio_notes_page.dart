import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// ✅ use the shared ApiConfig
import '../config/api_config.dart';

class AudioNotesPage extends StatefulWidget {
  final String channelName;
  final String username;
  final String token;

  const AudioNotesPage({
    super.key,
    required this.channelName,
    required this.username,
    required this.token,
  });

  @override
  State<AudioNotesPage> createState() => _AudioNotesPageState();
}

class _AudioNotesPageState extends State<AudioNotesPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentlyPlayingPath;

  bool _loading = true;
  List<Map<String, dynamic>> _audioList = [];
  File? _recordedFile;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _player.openPlayer();
    _fetchAudioFiles();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  Future<void> _fetchAudioFiles() async {
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
          'file_type': 'M4A',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _audioList = List<Map<String, dynamic>>.from(data['files']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showError('Failed to load audio files');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error loading audio files: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/temp_recording.m4a';
      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.aacMP4,
      );
      setState(() {
        _isRecording = true;
        _recordedFile = File(path);
      });
    } catch (e) {
      _showError("Failed to start recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        if (path != null) _recordedFile = File(path);
      });

      if (_recordedFile != null) {
        await _uploadAudio(_recordedFile!);
      }
    } catch (e) {
      _showError("Failed to stop recording: $e");
    }
  }

  Future<void> _uploadAudio(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.buildUrl('/files/upload')),
      );
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['user'] = widget.username;
      request.fields['channel'] = widget.channelName;
      request.fields['file_type'] = 'M4A';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('audio', 'mp4'),
        ),
      );

      final response = await request.send();
      if (response.statusCode == 201) {
        _showSuccess("Recording uploaded successfully!");
        _fetchAudioFiles(); // refresh list
      } else {
        _showError("Failed to upload recording");
      }
    } catch (e) {
      _showError("Upload failed: $e");
    }
  }

  Future<void> _playRemote(String url) async {
    if (_isPlaying && _currentlyPlayingPath == url) {
      await _player.stopPlayer();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingPath = null;
      });
      return;
    }

    await _player.startPlayer(
      fromURI: url,
      codec: Codec.aacMP4,
      whenFinished: () {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
        });
      },
    );

    setState(() {
      _isPlaying = true;
      _currentlyPlayingPath = url;
    });
  }

  Future<void> _toggleLike(Map<String, dynamic> audio) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.buildUrl('/files/MediaFiles/toggle-like')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'channel': widget.channelName,
          'file_no': audio['file_no'],
          'file_type': 'M4A',
          'username': widget.username,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          audio['likes'] = data['likes'];
          audio['liked'] = data['liked']; 
        });
      } else {
        _showError('Failed to update like');
      }
    } catch (e) {
      _showError('Error updating like: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.channelName} - Recordings',
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
          : _audioList.isEmpty
              ? const Center(
                  child: Text(
                    'No recordings yet.\nTap the mic to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _audioList.length,
                  itemBuilder: (context, index) {
                    final audio = _audioList[index];
                    final fileUrl = ApiConfig.buildUrl('/${audio['filepath']}');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.audiotrack, color: Colors.blue, size: 40),
                            const SizedBox(width: 16),

                            // File info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(audio['filename'] ?? 'Unknown file',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text("By: ${audio['user']}",
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text("Uploaded: ${audio['uploaded_at']}",
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),

                                  const SizedBox(height: 6),

                                  // 👇 Likes + counter
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () => _toggleLike(audio),
                                        icon: (audio['liked'] ??
                                                (audio['liked_by'] != null &&
                                                    audio['liked_by'].contains(widget.username)))
                                            ? const Icon(Icons.thumb_up, color: Colors.black)      // liked → black filled
                                            : const Icon(Icons.thumb_up_outlined, color: Colors.black), // not liked → white outline
                                      ),
                                      Text(
                                        '${audio['likes'] ?? 0} Likes',
                                        style: const TextStyle(fontSize: 14, color: Colors.black),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Play/Stop button
                            IconButton(
                              icon: Icon(
                                _isPlaying && _currentlyPlayingPath == fileUrl
                                    ? Icons.stop
                                    : Icons.play_arrow,
                                color: Colors.black,
                              ),
                              onPressed: () => _playRemote(fileUrl),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: "record",
        onPressed: _isRecording ? _stopRecording : _startRecording,
        backgroundColor: Colors.black,
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
        ),
      ),
    );
  }
}
