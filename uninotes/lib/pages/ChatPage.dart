import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ChatPage extends StatefulWidget {
  final String channelName;
  final String username;
  final String token;

  const ChatPage({
    super.key,
    required this.channelName,
    required this.username,
    required this.token,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  final int _pageSize = 20;
  int _skip = 0;

  final List<Color> _otherUserShades = [
    const Color.fromARGB(255, 170, 170, 170),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchInitialMessages();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 50 &&
        !_isLoadingMore &&
        _hasMore &&
        !_loading) {
      _loadMoreMessages();
    }
  }

  String _prettifyChannelName(String raw) {
    return raw.replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchInitialMessages() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse(ApiConfig.buildUrl('/chat/messages'));

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "channel": widget.channelName,
          "start": 0,
          "end": _pageSize,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List msgList = data['messages'] ?? [];

        // API returns newest first, but we need oldest->newest in UI
        msgList = msgList.reversed.toList();

        setState(() {
          messages.clear();
          messages.addAll(List<Map<String, dynamic>>.from(msgList));
          _skip = msgList.length;
          _hasMore = msgList.length == _pageSize;
        });

        // scroll to bottom after layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

            // force again next frame to avoid "stopping too early"
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent);
              }
            });
          }
        });
      } else {
        debugPrint('Error fetching messages: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || !_scrollController.hasClients) return;

    _isLoadingMore = true;
    setState(() {});

    // Step 1: Record current scroll position & max extent
    final double prevScrollOffset = _scrollController.offset;
    final double prevMaxExtent = _scrollController.position.maxScrollExtent;

    try {
      final uri = Uri.parse(ApiConfig.buildUrl('/chat/messages'));
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "channel": widget.channelName,
          "start": _skip,
          "end": _skip + _pageSize,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List fetched = data['messages'] ?? [];
        fetched = fetched.reversed.toList();

        if (fetched.isNotEmpty) {
          final olderMessages = List<Map<String, dynamic>>.from(fetched);
          messages.insertAll(0, olderMessages);

          _skip += olderMessages.length;
          if (olderMessages.length < _pageSize) _hasMore = false;

          setState(() {});

          // Step 2: After rebuild, restore exact offset
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final double newMaxExtent = _scrollController.position.maxScrollExtent;
            final double scrollOffsetCorrection = newMaxExtent - prevMaxExtent;

            _scrollController.jumpTo(prevScrollOffset + scrollOffsetCorrection);
          });
        } else {
          _hasMore = false;
        }
      } else {
        debugPrint('Error loading older messages: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error loading older messages: $e');
    } finally {
      _isLoadingMore = false;
      setState(() {});
    }
  }

  Future<void> sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    _controller.clear();

    try {
      final uri = Uri.parse(ApiConfig.buildUrl('/chat/message'));
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user": widget.username,
          "content": content,
          "channel": widget.channelName,
        }),
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final msg = body['message'] as Map<String, dynamic>;

        setState(() {
          messages.add(msg);
          _skip += 1;
        });

        _scrollToBottom();
      } else {
        debugPrint('Error sending message: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Widget _messageBubble(Map<String, dynamic> msg) {
    final isMine = msg['user'] == widget.username;
    final otherUser = msg['user'] ?? '';
    final colorIndex = otherUser.hashCode % _otherUserShades.length;
    final bubbleColor = isMine ? Colors.white : _otherUserShades[colorIndex];

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: isMine ? Border.all(color: Colors.black, width: 1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(
                msg['user'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              msg['content'] ?? '',
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 6),
            Text(
              msg['sent_at'] ?? '',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_prettifyChannelName(widget.channelName)),
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _messageBubble(messages[index]);
                        },
                      ),
                      if (_isLoadingMore)
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Loading older messages...',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.black87),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
