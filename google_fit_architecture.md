# Google Fit Data Architecture

## Overview
The app uses a **layered architecture** with multiple managers and services to handle Google Fit data from API to UI display.

## Architecture Layers

### 1. **Data Layer (API)**
```
GoogleFitService (Singleton)
├── Handles Google Fit API authentication
├── Makes HTTP requests to Google Fit endpoints
├── Manages OAuth tokens and refresh
└── Provides raw fitness data (steps, calories, workouts)
```

### 2. **Manager Layer (Coordination)**
```
GlobalGoogleFitManager (Singleton)
├── Auto-syncs data every 5 minutes
├── Manages connection state globally
├── Provides streams for data updates
└── Handles background sync across all screens

UnifiedGoogleFitManager (Singleton)
├── Single source of truth for Google Fit data
├── Coordinates between GlobalGoogleFitManager and GoogleFitService
├── Provides unified streams (data, connection, loading)
├── Prevents data conflicts
└── Optimizes performance with caching
```

### 3. **Model Layer (Data Structure)**
```
GoogleFitData Model
├── date: DateTime
├── steps: int?
├── caloriesBurned: double?
├── workoutSessions: int?
└── workoutDuration: double?
```

### 4. **UI Layer (Presentation)**
```
AnalyticsScreen
├── Uses GoogleFitSyncMixin for automatic sync
├── Subscribes to UnifiedGoogleFitManager streams
├── Displays data in Daily/Weekly views
└── Handles UI updates with setState()

GoogleFitSyncMixin
├── Provides automatic Google Fit sync to any screen
├── Handles connection state changes
├── Manages data updates
└── Ensures proper cleanup
```

## Data Flow

### Initialization Flow:
1. **AnalyticsScreen.initState()** → calls `_initializeGoogleFitData()`
2. **UnifiedGoogleFitManager.initialize()** → initializes services
3. **GlobalGoogleFitManager.ensureSync()** → starts auto-sync
4. **GoogleFitService.authenticate()** → handles OAuth
5. **Data streams** → start broadcasting updates

### Data Update Flow:
1. **GoogleFitService** → fetches data from Google Fit API
2. **GlobalGoogleFitManager** → processes and broadcasts sync data
3. **UnifiedGoogleFitManager** → receives and unifies data
4. **AnalyticsScreen** → receives data via streams
5. **UI** → updates with `setState()`

### Error Handling Flow:
1. **Network errors** → fallback to cached data
2. **Authentication errors** → retry with fresh tokens
3. **API errors** → show default values
4. **Connection loss** → continue with last known data

## Key Features

### Performance Optimizations:
- **Singleton pattern** for all managers
- **Stream-based updates** for real-time data
- **Debounced UI updates** (300ms minimum interval)
- **Background sync** every 5 minutes
- **Caching** for offline functionality

### Error Resilience:
- **Network connectivity checks**
- **Automatic retry mechanisms**
- **Fallback to cached data**
- **Graceful degradation**

### State Management:
- **Stream controllers** for reactive updates
- **Connection state tracking**
- **Loading state management**
- **Data validity timestamps**

## Current Issues & Solutions

### Issues:
1. **setState() after dispose** → Fixed with mounted checks
2. **Null data display** → Fixed with default values
3. **Excessive refreshes** → Fixed with debouncing
4. **Network errors** → Handled with fallbacks

### Solutions Implemented:
1. **Non-nullable GoogleFitData** with default values
2. **Proper stream cleanup** in dispose()
3. **Mounted checks** before setState()
4. **Cached data fallback** for offline mode
