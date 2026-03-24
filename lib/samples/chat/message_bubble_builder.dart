import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../models/chat_timeline.dart';
import 'message_bubble_content.dart';
import 'message_timestamp.dart';
import 'reply_preview_widget.dart';

class MessageBubbleBuilder extends StatefulWidget {
  final ChatMessage message;
  final ChatTimeline timeline;
  final BoxConstraints availableBubbleConstraints;
  final bool selectMode;
  final ValueChanged<String>? scrollToMessageId;
  final ValueChanged<ChatMessage>? onSelect;
  final ChatMessage? nextMessage;
  final bool animated;
  final bool compactMode;
  final String uiId;

  const MessageBubbleBuilder({
    super.key,
    required this.message,
    required this.timeline,
    required this.availableBubbleConstraints,
    required this.uiId,
    this.onSelect,
    this.nextMessage,
    this.scrollToMessageId,
    this.selectMode = false,
    this.animated = true,
    this.compactMode = false,
  });

  @override
  State<MessageBubbleBuilder> createState() => _MessageBubbleBuilderState();
}

class _MessageBubbleBuilderState extends State<MessageBubbleBuilder> {
  bool _replyLoaded = false;
  ChatMessage? _replyMessage;

  /// Once the bubble settles, we lock its width and do not expand it again.
  bool _settled = false;
  double? _settledWidth;

  void _setSettledWidthForCurrentMaxWidth() {
    final maxWidth = widget.availableBubbleConstraints.maxWidth;
    final bodyStepWidth = _computeStepWidth(context);

    if (_isTextMultiLine(context, widget.message.text, maxWidth)) {
      _settledWidth = bodyStepWidth ?? maxWidth;
      return;
    }

    if (_replyMessage != null) {
      if (_isTextMultiLine(context, _replyMessage!.text, maxWidth)) {
        _settledWidth = maxWidth;
        return;
      }

      _settledWidth = bodyStepWidth;
      return;
    }

    _settledWidth = bodyStepWidth;
  }

  void _recalculateSettledWidth() {
    if (!_settled || !_replyLoaded) return;
    _setSettledWidthForCurrentMaxWidth();
  }

  void _onReplyLoaded(ChatMessage replyMessage) {
    if (!mounted || _replyLoaded) return;
    setState(() {
      _replyLoaded = true;
      _replyMessage = replyMessage;
      _trySettle();
    });
  }

  void _trySettle() {
    if (_settled) return;
    if (!_replyLoaded) return;
    if (widget.message.deliveryStatus == MessageDeliveryStatus.sending) return;

    _settled = true;
    _setSettledWidthForCurrentMaxWidth();
  }

  bool _isTextMultiLine(BuildContext context, String text, double maxWidth) {
    if (text.isEmpty) return false;

    final style = Theme.of(context).textTheme.bodyMedium;
    final painter = TextPainter(
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
    )..layout(
        minWidth: 0,
        maxWidth: (maxWidth - 24).clamp(0.0, double.infinity),
      );

    final singleLineHeight = painter.preferredLineHeight;
    final isMultiLine = painter.height > singleLineHeight * 1.1;
    painter.dispose();
    return isMultiLine;
  }

  double? _computeStepWidth(BuildContext context) {
    return estimateBubbleWidth(
      context,
      text: widget.message.text,
      maxWidth: widget.availableBubbleConstraints.maxWidth,
      isEdited: widget.message.isEdited,
    );
  }

  Widget? _buildForwardedHeader(BuildContext context, ChatMessage message) {
    if (!message.isForwarded) return null;
    if (message.kind == MessageKind.image || message.kind == MessageKind.video) {
      return null;
    }

    final color = message.isOwn
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        const SizedBox(width: 8),
        Icon(Icons.forward, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          message.forwardedFrom?.isNotEmpty == true
              ? message.forwardedFrom!
              : 'Forwarded',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildMessageStack(
    BuildContext context, {
    required ChatMessage message,
    required Color textColor,
  }) {
    final endOfBubbleWidget =
        message.kind == MessageKind.sticker || message.kind == MessageKind.file
            ? MessageTimestamp(message: message)
            : const SizedBox.shrink();

    return Stack(
      children: [
        MessageBubbleContent(
          message: message,
          textColor: textColor,
          animated: widget.animated,
          timeline: widget.timeline,
          endOfBubbleWidget: endOfBubbleWidget,
          backgroundColor: message.isOwn
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          onTapSelectMode: () {
            if (!widget.selectMode) return;
            widget.onSelect?.call(message);
          },
          ownMessage: message.isOwn,
          compactMode: widget.compactMode,
        ),
        if (message.showOverlayTimestamp)
          Positioned(
            right: 6,
            bottom: 6,
            child: SelectionContainer.disabled(
              child: MessageTimestamp(message: message),
            ),
          ),
      ],
    );
  }

  Widget? _buildReplyPreview(ChatMessage message, {required bool hasReply}) {
    if (!hasReply) return null;

    final replyId = message.replyToMessageId!;
    return ReplyPreviewWidget(
      key: ValueKey('reply:${widget.uiId}:$replyId'),
      message: message,
      timeline: widget.timeline,
      scrollToMessageId: widget.scrollToMessageId,
      messageUiId: widget.uiId,
      isOwnMessage: message.isOwn,
      onReplyLoaded: _onReplyLoaded,
    );
  }

  Widget? _buildEditedSpacer(ChatMessage message) {
    if (!message.isEdited) return null;
    return const SizedBox(height: 8);
  }

  Widget? _buildInvisibleTimestampSpacer(
    ChatMessage message, {
    required bool needsNewLineForTimestamp,
  }) {
    final shouldReserveSpace =
        needsNewLineForTimestamp || containsRichMarkup(message.text);

    if (!shouldReserveSpace || message.isEdited) return null;

    return Visibility(
      visible: false,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: SelectionContainer.disabled(
        child: MessageTimestamp(message: message),
      ),
    );
  }

  Widget _buildBubbleChild({
    required Widget content,
    required bool disableIntrinsicWidth,
    required bool hasReply,
    required double? stepWidth,
    required double maxBubbleWidth,
  }) {
    if (disableIntrinsicWidth && !hasReply) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: content,
      );
    }

    if (hasReply) {
      if (_settled) {
        final width = _settledWidth;
        if (width != null) {
          return SizedBox(width: width, child: content);
        }
        return IntrinsicWidth(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: content,
          ),
        );
      }
      return SizedBox(width: maxBubbleWidth, child: content);
    }

    if (stepWidth != null) {
      return SizedBox(width: stepWidth, child: content);
    }

    return IntrinsicWidth(child: content);
  }

  Widget _buildBubbleContent(
    BuildContext context, {
    required ChatMessage message,
    required Color textColor,
    required bool needsNewLineForTimestamp,
    required bool hasReply,
  }) {
    final forwardedHeader = _buildForwardedHeader(context, message);
    final replyPreview = _buildReplyPreview(message, hasReply: hasReply);
    final editedSpacer = _buildEditedSpacer(message);
    final invisibleTimestampSpacer = _buildInvisibleTimestampSpacer(
      message,
      needsNewLineForTimestamp: needsNewLineForTimestamp,
    );

    return KeyedSubtree(
      key: ValueKey('message-content-${widget.uiId}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (forwardedHeader != null) ...[
            forwardedHeader,
            const SizedBox(height: 8),
          ],
          if (replyPreview != null) replyPreview,
          _buildMessageStack(
            context,
            message: message,
            textColor: textColor,
          ),
          if (editedSpacer != null) editedSpacer,
          if (invisibleTimestampSpacer != null) invisibleTimestampSpacer,
        ],
      ),
    );
  }

  bool _noBottomPadding(ChatMessage message) =>
      (widget.compactMode && !message.isOwn) ||
      {MessageKind.file, MessageKind.audio}.contains(message.kind);

  @override
  void didUpdateWidget(covariant MessageBubbleBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    final messageIdChanged = oldWidget.message.id != widget.message.id;
    final uiIdChanged = oldWidget.uiId != widget.uiId;

    // Reset sticky state only when the State instance is reused for a different
    // message. Ignore local id -> server id transitions if UI identity is stable.
    if (messageIdChanged && uiIdChanged) {
      _replyLoaded = false;
      _replyMessage = null;
      _settled = false;
      _settledWidth = null;
    }

    final oldMaxWidth = oldWidget.availableBubbleConstraints.maxWidth;
    final newMaxWidth = widget.availableBubbleConstraints.maxWidth;
    final maxWidthDelta = (oldMaxWidth - newMaxWidth).abs();

    final significantMaxWidthChangeThreshold =
        (newMaxWidth * 0.08).clamp(16.0, 48.0);
    final significantMaxWidthChanged =
        maxWidthDelta >= significantMaxWidthChangeThreshold;

    if (significantMaxWidthChanged) {
      _recalculateSettledWidth();
    }

    final statusBecameNonSending =
        oldWidget.message.deliveryStatus == MessageDeliveryStatus.sending &&
            widget.message.deliveryStatus != MessageDeliveryStatus.sending;

    if (!_settled && _replyLoaded && statusBecameNonSending) {
      _trySettle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final message = widget.message;

    final hasReply = message.replyToMessageId != null;
    final noPadding = _noBottomPadding(message);

    final bubbleMetrics = calculateBubbleMetrics(
      context,
      text: message.text,
      maxWidth: widget.availableBubbleConstraints.maxWidth,
      isEdited: message.isEdited,
      hasReply: hasReply,
    );

    final stepWidth = hasReply ? null : bubbleMetrics.totalWidth;
    final needsNewLineForTimestamp =
        bubbleMetrics.needsNewLineForTimestamp;

    final disableIntrinsicWidth =
        containsRichMarkup(message.text) || widget.compactMode;

    final content = _buildBubbleContent(
      context,
      message: message,
      textColor: textColor,
      needsNewLineForTimestamp: needsNewLineForTimestamp,
      hasReply: hasReply,
    );

    final maxBubbleWidth = widget.availableBubbleConstraints.maxWidth;

    final bubbleChild = _buildBubbleChild(
      content: content,
      disableIntrinsicWidth: disableIntrinsicWidth,
      hasReply: hasReply,
      stepWidth: stepWidth,
      maxBubbleWidth: maxBubbleWidth,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: _topPaddingFor(message),
        bottom: noPadding || message.showOverlayTimestamp ? 0 : 8,
      ),
      child: bubbleChild,
    );
  }

  double _topPaddingFor(ChatMessage message) {
    if (message.kind == MessageKind.image ||
        message.kind == MessageKind.video ||
        message.kind == MessageKind.audio) {
      return 0;
    }
    return 8;
  }
}

/// ---- Public sample helpers ----

class BubbleMetrics {
  final double? totalWidth;
  final bool needsNewLineForTimestamp;

  const BubbleMetrics({
    required this.totalWidth,
    required this.needsNewLineForTimestamp,
  });
}

BubbleMetrics calculateBubbleMetrics(
  BuildContext context, {
  required String text,
  required double maxWidth,
  required bool isEdited,
  required bool hasReply,
}) {
  final width = estimateBubbleWidth(
    context,
    text: text,
    maxWidth: maxWidth,
    isEdited: isEdited,
  );

  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: (maxWidth - 24).clamp(0.0, double.infinity));

  final needsNewLine = painter.height > painter.preferredLineHeight * 1.1;
  painter.dispose();

  return BubbleMetrics(
    totalWidth: hasReply ? null : width,
    needsNewLineForTimestamp: needsNewLine,
  );
}

double? estimateBubbleWidth(
  BuildContext context, {
  required String text,
  required double maxWidth,
  required bool isEdited,
}) {
  if (text.trim().isEmpty) return null;

  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout(maxWidth: maxWidth);

  const horizontalPadding = 24.0;
  const timestampReserve = 56.0;
  final editedReserve = isEdited ? 24.0 : 0.0;

  final estimated =
      painter.width + horizontalPadding + timestampReserve + editedReserve;

  painter.dispose();
  return estimated.clamp(0.0, maxWidth);
}

bool containsRichMarkup(String text) {
  return text.contains('<') && text.contains('>');
}
