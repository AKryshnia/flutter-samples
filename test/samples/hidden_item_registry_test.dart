import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../lib/utils/hidden_item_registry.dart';
import 'hidden_item_registry_test.mocks.dart';

@GenerateMocks([ChatRoom, ChatClient, AccountDataEvent])
void main() {
  group('HiddenItemRegistry', () {
    late MockChatRoom mockRoom;
    late MockChatClient mockClient;

    setUp(() {
      mockRoom = MockChatRoom();
      mockClient = MockChatClient();

      when(mockRoom.client).thenReturn(mockClient);
      when(mockRoom.id).thenReturn('room-1');
      when(mockClient.userId).thenReturn('user-1');
      when(mockRoom.roomAccountData).thenReturn({});
    });

    test('getHiddenItemIds returns empty set when no account data', () async {
      when(mockRoom.roomAccountData).thenReturn({});

      final result = await HiddenItemRegistry.getHiddenItemIds(mockRoom);

      expect(result, isEmpty);
    });

    test('getHiddenItemIds returns hidden item IDs from account data',
        () async {
      final mockAccountData = MockAccountDataEvent();
      when(mockAccountData.content).thenReturn({
        'hidden_item_ids': ['item-1', 'item-2', 'item-3'],
      });
      when(mockRoom.roomAccountData)
          .thenReturn({'com.example.hidden_items': mockAccountData});

      final result = await HiddenItemRegistry.getHiddenItemIds(mockRoom);

      expect(result, {'item-1', 'item-2', 'item-3'});
    });

    test('getHiddenItemIds handles invalid data gracefully', () async {
      final mockAccountData = MockAccountDataEvent();
      when(mockAccountData.content).thenReturn({
        'hidden_item_ids': 'invalid_not_a_list',
      });
      when(mockRoom.roomAccountData)
          .thenReturn({'com.example.hidden_items': mockAccountData});

      final result = await HiddenItemRegistry.getHiddenItemIds(mockRoom);

      expect(result, isEmpty);
    });

    test('getHiddenItemIdsList returns ordered list', () async {
      final mockAccountData = MockAccountDataEvent();
      when(mockAccountData.content).thenReturn({
        'hidden_item_ids': ['item-1', 'item-2', 'item-3'],
      });
      when(mockRoom.roomAccountData)
          .thenReturn({'com.example.hidden_items': mockAccountData});

      final result = await HiddenItemRegistry.getHiddenItemIdsList(mockRoom);

      expect(result, ['item-1', 'item-2', 'item-3']);
      expect(result, isA<List<String>>());
    });

    test('getHiddenItemIdsList returns empty list when no account data',
        () async {
      when(mockRoom.roomAccountData).thenReturn({});

      final result = await HiddenItemRegistry.getHiddenItemIdsList(mockRoom);

      expect(result, isEmpty);
      expect(result, isA<List<String>>());
    });

    test('addHiddenItem adds item ID to account data', () async {
      when(mockRoom.roomAccountData).thenReturn({});
      when(mockClient.setAccountDataPerRoom(any, any, any, any))
          .thenAnswer((_) async => {});

      await HiddenItemRegistry.addHiddenItem(mockRoom, 'new-item');

      verify(
        mockClient.setAccountDataPerRoom(
          'user-1',
          'room-1',
          'com.example.hidden_items',
          {
            'hidden_item_ids': ['new-item'],
          },
        ),
      ).called(1);
    });

    test('addHiddenItem enforces max limit of 500 items', () async {
      final existingItems = List.generate(500, (i) => 'item-$i');
      final mockAccountData = MockAccountDataEvent();
      when(mockAccountData.content).thenReturn({
        'hidden_item_ids': existingItems,
      });
      when(mockRoom.roomAccountData)
          .thenReturn({'com.example.hidden_items': mockAccountData});
      when(mockClient.setAccountDataPerRoom(any, any, any, any))
          .thenAnswer((_) async => {});

      await HiddenItemRegistry.addHiddenItem(mockRoom, 'item-500');

      final captured = verify(
        mockClient.setAccountDataPerRoom(
          'user-1',
          'room-1',
          'com.example.hidden_items',
          captureAny,
        ),
      ).captured.single as Map<String, dynamic>;

      final hiddenList = captured['hidden_item_ids'] as List;
      expect(hiddenList.length, 500);
      expect(hiddenList.first, 'item-1');
      expect(hiddenList.last, 'item-500');
    });

    test('addHiddenItem moves duplicate to end (preserves FIFO order)',
        () async {
      final mockAccountData = MockAccountDataEvent();
      when(mockAccountData.content).thenReturn({
        'hidden_item_ids': ['item-1', 'item-2', 'item-3'],
      });
      when(mockRoom.roomAccountData)
          .thenReturn({'com.example.hidden_items': mockAccountData});
      when(mockClient.setAccountDataPerRoom(any, any, any, any))
          .thenAnswer((_) async => {});

      await HiddenItemRegistry.addHiddenItem(mockRoom, 'item-2');

      final captured = verify(
        mockClient.setAccountDataPerRoom(
          'user-1',
          'room-1',
          'com.example.hidden_items',
          captureAny,
        ),
      ).captured.single as Map<String, dynamic>;

      final hiddenList = captured['hidden_item_ids'] as List;
      expect(hiddenList, ['item-1', 'item-3', 'item-2']);
      expect(hiddenList.last, 'item-2');
    });

    test('isItemHidden returns true for hidden item', () async {
      final mockAccountData = MockAccountDataEvent();
      when(mockAccountData.content).thenReturn({
        'hidden_item_ids': ['hidden-1', 'hidden-2'],
      });
      when(mockRoom.roomAccountData)
          .thenReturn({'com.example.hidden_items': mockAccountData});

      final result =
          await HiddenItemRegistry.isItemHidden(mockRoom, 'hidden-1');

      expect(result, isTrue);
    });

    test('isItemHidden returns false for non-hidden item', () async {
      final mockAccountData = MockAccountDataEvent();
      when(mockAccountData.content).thenReturn({
        'hidden_item_ids': ['hidden-1', 'hidden-2'],
      });
      when(mockRoom.roomAccountData)
          .thenReturn({'com.example.hidden_items': mockAccountData});

      final result =
          await HiddenItemRegistry.isItemHidden(mockRoom, 'visible-item');

      expect(result, isFalse);
    });

    test('removeHiddenItem removes item ID from account data', () async {
      final mockAccountData = MockAccountDataEvent();
      when(mockAccountData.content).thenReturn({
        'hidden_item_ids': ['item-1', 'item-2', 'item-3'],
      });
      when(mockRoom.roomAccountData)
          .thenReturn({'com.example.hidden_items': mockAccountData});
      when(mockClient.setAccountDataPerRoom(any, any, any, any))
          .thenAnswer((_) async => {});

      await HiddenItemRegistry.removeHiddenItem(mockRoom, 'item-2');

      final captured = verify(
        mockClient.setAccountDataPerRoom(
          'user-1',
          'room-1',
          'com.example.hidden_items',
          captureAny,
        ),
      ).captured.single as Map<String, dynamic>;

      final hiddenList = captured['hidden_item_ids'] as List;
      expect(hiddenList, ['item-1', 'item-3']);
      expect(hiddenList, isNot(contains('item-2')));
    });

    test('clearHiddenItems clears all hidden items', () async {
      when(mockClient.setAccountDataPerRoom(any, any, any, any))
          .thenAnswer((_) async => {});

      await HiddenItemRegistry.clearHiddenItems(mockRoom);

      verify(
        mockClient.setAccountDataPerRoom(
          'user-1',
          'room-1',
          'com.example.hidden_items',
          {'hidden_item_ids': []},
        ),
      ).called(1);
    });
  });
}
