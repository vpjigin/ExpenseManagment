# Expense Management App - Setup Guide

## Architecture Overview

This app follows a **clean-ish layered architecture** with the following structure:

```
lib/
├── core/           # Shared utilities, constants, extensions
│   └── utils/      # Utility classes (UUID generator, etc.)
├── data/           # Data layer
│   ├── database/   # Drift database configuration
│   ├── tables/     # Drift table definitions
│   └── repositories/ # Repository implementations
├── domain/         # Business logic layer
│   └── entities/   # Domain entities (Freezed models)
├── application/    # Application layer
│   ├── providers/  # Riverpod providers
│   └── notifiers/  # StateNotifier implementations
└── presentation/   # UI layer
    ├── screens/    # Screen widgets
    ├── widgets/    # Reusable widgets
    └── routing/    # go_router configuration
```

## Tech Stack

- **State Management**: Riverpod (StateNotifier/Notifier)
- **Navigation**: go_router
- **Local Storage**: Drift (SQL with UUID string IDs)
- **Dependency Injection**: Built-in via Riverpod providers
- **Code Generation**: Freezed, json_serializable, Drift

## Key Features

✅ **UUID String IDs**: All database tables use UUID string IDs (not auto-increment integers) for easy cloud sync
✅ **Type-Safe**: Full type safety with Drift and Freezed
✅ **Clean Architecture**: Separation of concerns across layers
✅ **Reactive State**: Riverpod for reactive state management

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Generate Code

Run code generation for Freezed, json_serializable, and Drift:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Or watch mode (auto-regenerates on file changes):

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

### 3. Run the App

```bash
flutter run
```

## Adding New Tables

When creating a new table:

1. Create the table in `lib/data/tables/` with UUID string ID:
   ```dart
   class MyTable extends Table {
     TextColumn get id => text()(); // UUID string, not auto-increment
     // ... other columns
     @override
     Set<Column> get primaryKey => {id};
   }
   ```

2. Add the table to `AppDatabase`:
   ```dart
   @DriftDatabase(tables: [Expenses, MyTable])
   ```

3. Run code generation:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

## UUID Usage

All entities should use UUID strings for IDs. Use the `UuidGenerator` utility:

```dart
import '../../core/utils/uuid_generator.dart';

final id = UuidGenerator.generate();
```

This ensures compatibility with cloud databases and prevents ID conflicts during sync.

## Project Structure Best Practices

- **Domain Layer**: Pure business logic, no dependencies on data/presentation
- **Data Layer**: Database operations, API calls, data transformations
- **Application Layer**: State management, business logic coordination
- **Presentation Layer**: UI components, routing, user interactions
