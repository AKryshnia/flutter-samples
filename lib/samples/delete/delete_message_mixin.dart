import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/chat_timeline.dart';
import '../utils/hidden_item_registry.dart';

mixin DeleteMessageMixin<T extends StatefulWidget> on State<T> {
  DeleteMessageUseCase get deleteMessageUseCase;
  HiddenItemRegistry get hiddenItemRegistry;

  StreamSubscription? _deleteMessageStreamSubscription;

  /// Override this getter to provide the active timeline instance
  /// for local item removal.
  ChatTimeline? get deleteMessageTimeline => null;

  /// Override this method to handle additional cleanup
  /// after a message is deleted locally.
  void onMessageDeletedLocally(ChatMessage message) {}

  /// UI hooks that the host widget can implement in its own way.
  Future<DeleteConfirmationResult?> showDeleteConfirmation(
    BuildContext context, {
    required bool canDeleteForEveryone,
  });

  void showErrorMessage(BuildContext context, String message);

  Future<bool> deleteMessageAction(
    BuildContext context,
    ChatMessage message,
  ) async {
    final confirmation = await showDeleteConfirmation(
      context,
      canDeleteForEveryone: message.canDeleteForEveryone,
    );
    if (confirmation == null) return false;

    if (!mounted) return false;

    final bool deleteForEveryone = confirmation.deleteForEveryone;

    if (deleteForEveryone) {
      _deleteMessageStreamSubscription?.cancel();
      _deleteMessageStreamSubscription = null;

      _deleteMessageStreamSubscription =
          deleteMessageUseCase.execute(message).listen(
        (result) {
          if (!mounted) return;

          result.when(
            permissionDenied: () {
              showErrorMessage(
                context,
                'You do not have permission to delete this message.',
              );
            },
            failed: () {
              showErrorMessage(context, 'Failed to delete message.');
            },
            success: () {},
          );
        },
        onError: (_) {
          if (!mounted) return;
          showErrorMessage(context, 'Failed to delete message.');
        },
        onDone: () {
          _deleteMessageStreamSubscription = null;
        },
      );
    } else {
      try {
        if (message.deliveryStatus == MessageDeliveryStatus.sent) {
          await hiddenItemRegistry.addHiddenItem(
            roomId: message.roomId,
            itemId: message.id,
          );

          final timeline = deleteMessageTimeline;
          if (timeline != null) {
            timeline.removeMessageById(message.id);
          }

          onMessageDeletedLocally(message);
        } else {
          await message.removeLocally();
        }
      } catch (_) {
        if (!mounted) return false;
        showErrorMessage(context, 'Failed to delete message.');
        return false;
      }
    }

    return true;
  }

  @mustCallSuper
  void disposeDeleteMessageMixin() {
    _deleteMessageStreamSubscription?.cancel();
    _deleteMessageStreamSubscription = null;
  }
}

class DeleteConfirmationResult {
  final bool deleteForEveryone;

  const DeleteConfirmationResult({
    required this.deleteForEveryone,
  });
}

abstract class DeleteMessageUseCase {
  Stream<DeleteMessageResult> execute(ChatMessage message);
}

sealed class DeleteMessageResult {
  const DeleteMessageResult();

  void when({
    required VoidCallback permissionDenied,
    required VoidCallback failed,
    required VoidCallback success,
  }) {
    final value = this;
    switch (value) {
      case DeletePermissionDenied():
        permissionDenied();
      case DeleteFailed():
        failed();
      case DeleteSucceeded():
        success();
    }
  }
}

class DeletePermissionDenied extends DeleteMessageResult {
  const DeletePermissionDenied();
}

class DeleteFailed extends DeleteMessageResult {
  const DeleteFailed();
}

class DeleteSucceeded extends DeleteMessageResult {
  const DeleteSucceeded();
}
