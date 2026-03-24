import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/chat_timeline.dart';
import 'reply_preview.dart';
import 'reply_preview_placeholder.dart';

class ReplyPreviewWidget extends StatefulWidget {
  const ReplyPreviewWidget({
    super.key,
    required this.message,
    required this.timeline,
    this.scrollToMessageId,
    this.isOwnMessage = false,

    /// Stable id for UI identity across localId -> serverId transitions.
    /// If null, falls back to [message.localId] / [message.id].
    this.messageUiId,

    /// Called once when reply message is resolved for the first time.
    this.onReplyLoaded,
  });

  final ChatMessage message;
  final ChatTimeline timeline;
  final ValueChanged<String>? scrollToMessageId;
  final bool isOwnMessage;
  final String? messageUiId;
  final ValueChanged<ChatMessage>? onReplyLoaded;

  @override
  State<ReplyPreviewWidget> createState() => _ReplyPreviewWidgetState();
}

class _ReplyPreviewWidgetState extends State<ReplyPreviewWidget> {
  ChatMessage? _replyMessage;
  Object? _loadError;

  int _loadSeq = 0;
  bool _didRetry = false;

  String? _lastStableMessageId;
  String? _lastReplyToMessageId;

  String _stableMessageId() {
    final fromCaller = widget.messageUiId;
    if (fromCaller != null && fromCaller.isNotEmpty) return fromCaller;

    final localId = widget.message.localId;
    if (localId != null && localId.isNotEmpty) return localId;

    return widget.message.id;
  }

  @override
  void initState() {
    super.initState();
    _reloadIfNeeded(force: true);
  }

  @override
  void didUpdateWidget(covariant ReplyPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reloadIfNeeded();
  }

  void _reloadIfNeeded({bool force = false}) {
    final stableMessageId = _stableMessageId();
    final replyToMessageId = widget.message.replyToMessageId;

    final replyTargetChanged = _lastReplyToMessageId != replyToMessageId;
    final stableMessageIdChanged = _lastStableMessageId != stableMessageId;

    final shouldReload = force ||
        replyTargetChanged ||
        (stableMessageIdChanged &&
            _replyMessage == null &&
            _loadError == null);

    if (!shouldReload) return;

    _lastStableMessageId = stableMessageId;
    _lastReplyToMessageId = replyToMessageId;
    _didRetry = false;

    _loadReplyMessage(clearCache: force);
  }

  Future<void> _loadReplyMessage({bool clearCache = false}) async {
    final mySeq = ++_loadSeq;

    // Show placeholder only on the first load.
    // Keep stale content visible during subsequent reloads to avoid flicker.
    if (clearCache || _replyMessage == null) {
      setState(() {
        _replyMessage = null;
        _loadError = null;
      });
    } else {
      if (_loadError != null) {
        setState(() {
          _loadError = null;
        });
      } else {
        _loadError = null;
      }
    }

    try {
      final replyMessage = await widget.timeline.resolveReply(widget.message);
      if (!mounted || mySeq != _loadSeq) return;

      final wasNull = _replyMessage == null;

      if (replyMessage?.id != _replyMessage?.id) {
        setState(() {
          _replyMessage = replyMessage;
        });
      }

      if (replyMessage != null && wasNull) {
        widget.onReplyLoaded?.call(replyMessage);
      }

      if (replyMessage == null) {
        _scheduleRetryIfNeeded(mySeq);
      }
    } catch (e) {
      if (!mounted || mySeq != _loadSeq) return;
      setState(() {
        _loadError = e;
      });
    }
  }

  void _scheduleRetryIfNeeded(int seq) {
    if (_didRetry) return;
    if (_lastReplyToMessageId == null) return;
    _didRetry = true;

    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (seq != _loadSeq) return;
      if (_replyMessage != null || _loadError != null) return;
      _loadReplyMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final replyMessage = _replyMessage;

    if (replyMessage == null && _loadError != null) {
      return const SizedBox.shrink();
    }

    final scrollTargetId =
        replyMessage?.id ?? widget.message.replyToMessageId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (widget.scrollToMessageId == null) return;
          if (scrollTargetId == null || scrollTargetId.isEmpty) return;
          widget.scrollToMessageId!(scrollTargetId);
        },
        child: AbsorbPointer(
          child: replyMessage != null
              ? ReplyPreview(
                  replyMessage: replyMessage,
                  isOwnMessage: widget.isOwnMessage,
                )
              : ReplyPreviewPlaceholder(
                  key: ValueKey(
                    'reply-placeholder:${widget.messageUiId ?? widget.message.id}',
                  ),
                  isOwnMessage: widget.isOwnMessage,
                ),
        ),
      ),
    );
  }
}
