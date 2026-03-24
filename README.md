# Flutter Code Samples / Примеры Flutter-кода

## English

This repository contains a small set of Flutter code samples adapted from a private product codebase.

The goal is not to show a full application, but to highlight several engineering tasks I worked on directly:

- async UI state handling
- stable widget identity during message state transitions
- complex chat bubble layout logic
- practical product-side deletion flow
- testing of edge cases and data consistency behavior

## Repository structure

```text
lib/
  samples/chat/
    reply_preview_widget.dart
    message_bubble_builder.dart
  samples/delete/
    delete_message_mixin.dart

test/
  samples/
    hidden_item_registry_test.dart
```

## What these samples demonstrate

### `reply_preview_widget.dart`

A reply preview widget for chat messages.

What it shows:

* asynchronous loading of replied message content
* protection against stale async results
* stable UI behavior during localId -> serverId transitions
* retry logic for delayed reply resolution
* avoiding flicker by preserving stale content during reloads

### `message_bubble_builder.dart`

A message bubble builder for chat UI.

What it shows:

* dynamic bubble width calculation
* reply-aware layout behavior
* timestamp placement logic
* rebuild control on significant layout changes only
* handling of tricky UI edge cases in production-like message rendering

### `delete_message_mixin.dart`

A reusable mixin for message deletion flows.

What it shows:

* separation of delete-for-everyone and delete-for-me behavior
* integration of UI confirmation with business logic
* local deletion flow with hidden-item persistence
* safe async handling in widget lifecycle

### `hidden_item_registry_test.dart`

Tests for hidden-item persistence logic.

What it shows:

* edge-case coverage
* FIFO behavior for capped stored items
* duplicate handling
* validation of ordered and unordered retrieval behavior

## Notes

These files were adapted from a private commercial codebase:

* project-specific names were removed
* internal dependencies were simplified
* product and domain details were intentionally generalized

The purpose of this repository is to show code style, engineering decisions, and approach to UI, state, and business logic, not to reproduce the original application.

## Focus

This sample set is intended to demonstrate:

* practical Flutter engineering
* product-oriented thinking
* attention to UI stability
* async and state-management discipline
* maintainable code structure

If needed, I can walk through any of these files and explain the design decisions behind them.

---

## Русский

В этом репозитории собрана небольшая подборка Flutter-файлов, адаптированных из приватного продуктового проекта.

Цель репозитория — не показать целое приложение, а продемонстрировать несколько инженерных задач, над которыми я работала лично:

* работа с асинхронным UI-состоянием
* стабильная identity-логика виджетов при переходах состояния сообщений
* сложная логика layout для chat bubbles
* прикладной сценарий удаления сообщений
* тестирование edge cases и поведения данных

## Структура репозитория

```text
lib/
  samples/chat/
    reply_preview_widget.dart
    message_bubble_builder.dart
  samples/delete/
    delete_message_mixin.dart

test/
  samples/
    hidden_item_registry_test.dart
```

## Что показывают эти примеры

### `reply_preview_widget.dart`

Виджет превью ответа в чате.

Что здесь показано:

* асинхронная загрузка replied message
* защита от устаревших async-результатов
* стабильное поведение UI при переходе localId -> serverId
* retry-логика для случаев, когда ответное сообщение появляется с задержкой
* отсутствие flicker за счёт сохранения старого контента во время перезагрузки

### `message_bubble_builder.dart`

Сборщик message bubble для chat UI.

Что здесь показано:

* динамический расчёт ширины bubble
* поведение layout с учётом reply-сценариев
* логика размещения timestamp
* контроль перестроений только при действительно значимых изменениях layout
* обработка сложных UI edge cases в production-like сообщениях

### `delete_message_mixin.dart`

Переиспользуемый mixin для сценария удаления сообщений.

Что здесь показано:

* разделение логики «удалить для всех» и «удалить только у себя»
* связка пользовательского подтверждения и бизнес-логики
* локальное удаление с сохранением скрытых элементов
* безопасная работа с async-логикой в lifecycle виджета

### `hidden_item_registry_test.dart`

Тесты для логики хранения скрытых элементов.

Что здесь показано:

* покрытие edge cases
* FIFO-поведение при ограничении размера хранилища
* обработка дублей
* проверка корректности ordered / unordered retrieval

## Примечания

Эти файлы адаптированы из приватного коммерческого проекта:

* проектные названия убраны
* внутренние зависимости упрощены
* продуктовые и доменные детали намеренно обобщены

Задача репозитория — показать стиль кода, инженерные решения и подход к UI, state и business logic, а не воспроизвести исходное приложение.

## Фокус

Эта подборка сделана для того, чтобы показать:

* практический Flutter engineering
* продуктовый подход
* внимание к стабильности UI
* дисциплину в async и state management
* поддерживаемую структуру кода

При необходимости я могу отдельно пояснить архитектурные решения и компромиссы в каждом из файлов.
