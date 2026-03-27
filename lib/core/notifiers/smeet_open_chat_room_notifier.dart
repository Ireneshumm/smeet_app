import 'package:flutter/foundation.dart';

/// Which chat room is treated as "open" for **display** unread (list rows + Chat aggregate).
///
/// [ChatRoomPage] sets/clears this; [ChatPage] and [InboxPage] listen so the open thread
/// shows 0 unread without writing shell badge directly.
final ValueNotifier<String?> smeetOpenChatRoomId = ValueNotifier<String?>(null);
