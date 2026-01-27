# Patient Home Page - Backend Integration

## Overview
The patient home page now integrates with the backend API to fetch real patient data including profile information, medical history (INR logs), and prescriptions.

## Architecture

### Service Layer: `lib/services/patient_service.dart`

The `PatientService` class handles all API communication with the backend:

#### Key Methods:

1. **`getProfile()`** 
   - Endpoint: `GET /api/patient/profile`
   - Returns: Patient basic info (name, age, gender, OP#, target INR, therapy drug, etc.)
   - Authentication: Bearer token from secure storage

2. **`getINRHistory()`**
   - Endpoint: `GET /api/patient/reports`
   - Returns: List of INR records with date, value, notes, and status
   - Processes: INR history from patient profile

3. **`getPrescriptions()`**
   - Endpoint: `GET /api/patient/reports`
   - Returns: List of prescriptions with drug, dosage, frequency, instructions
   - Processes: Extracts therapy drug from medical config + static medications

4. **`getLatestINR()`**
   - Endpoint: `GET /api/patient/reports`
   - Returns: Latest INR value (double)
   - Processes: Gets first INR from history list

#### Helper Methods:
- `_formatDate()` - Converts ISO dates to DD-MM-YYYY format
- `_getINRStatus()` - Determines if INR is Normal/Low/High based on target range
- `_setupInterceptors()` - Adds JWT token to request headers

### Authentication

The service automatically:
1. Reads JWT token from `FlutterSecureStorage` (key: `auth_token`)
2. Adds it to request headers: `Authorization: Bearer {token}`
3. Handles unauthorized responses with error messages

## Data Flow

```
PatientHomePage (_PatientHomePageState)
    ↓
    initState() → _loadPatientData()
    ↓
    PatientService.getProfile()     → User + PatientProfile data
    PatientService.getINRHistory()  → INR logs list
    PatientService.getPrescriptions() → Prescriptions list
    PatientService.getLatestINR()   → Latest INR value
    ↓
    setState() updates UI with real data
    ↓
    Render: Patient card, Medical history, Prescriptions
```

## UI States Handled

1. **Loading State**
   - Shows `CircularProgressIndicator` while fetching data
   - Displays: "@ Patient Home" header only

2. **Error State**
   - Shows error icon + message
   - Displays: "Error Loading Data" with error details
   - Provides: "Retry" button to reload data

3. **Data Loaded State**
   - Shows all sections with real data
   - Includes: `RefreshIndicator` for pull-to-refresh
   - Shows "No data" messages if lists are empty

## Backend API Requirements

### Endpoints Used:

#### 1. `GET /api/patient/profile`
```typescript
Response:
{
  "data": {
    "patient": {
      "_id": "user_id",
      "profile_id": {
        "demographics": {
          "name": string,
          "age": number,
          "gender": string,
          "phone": string
        },
        "medical_config": {
          "therapy_drug": string,
          "therapy_start_date": Date,
          "target_inr": { min: number, max: number },
          "next_review_date": Date,
          "instructions": string[]
        }
      }
    }
  }
}
```

#### 2. `GET /api/patient/reports`
```typescript
Response:
{
  "data": {
    "report": {
      "inr_history": [
        {
          "test_date": Date,
          "inr_value": number,
          "notes": string,
          "is_critical": boolean
        }
      ],
      "weekly_dosage": {...},
      "medical_config": {...}
    }
  }
}
```

## Required Packages

All required packages are already in `pubspec.yaml`:

```yaml
dio: ^5.9.0                           # HTTP client
flutter_secure_storage: ^10.0.0       # Secure token storage
```

## Usage in Other Pages

To use the service in other patient pages:

```dart
import 'package:frontend/services/patient_service.dart';

// Fetch data
final profile = await PatientService.getProfile();
final history = await PatientService.getINRHistory();
final prescriptions = await PatientService.getPrescriptions();

// Handle errors
try {
  final data = await PatientService.getProfile();
} catch (e) {
  print('Error: $e');
}
```

## Environment Configuration

Update the baseUrl in `patient_service.dart` based on your environment:

```dart
// Development (local machine)
static const String baseUrl = 'http://localhost:3000/api/patient';

// Production (deployed API)
static const String baseUrl = 'https://api.yourdomain.com/api/patient';
```

## Testing

1. **Ensure backend is running:**
   ```bash
   cd backend
   npm install
   npm run dev
   ```

2. **Run the app:**
   ```bash
   flutter run -d chrome
   ```

3. **Check console for errors:**
   - Token not found: Ensure user is logged in
   - Network error: Check backend URL and port
   - 401 Unauthorized: Verify token is valid
   - 404 Not Found: Check backend endpoints are implemented

## Error Handling

The service throws exceptions with descriptive messages:

- `"Error: Connection timeout"` - Network unreachable
- `"Error: 401 Unauthorized"` - Invalid/expired token
- `"Error: 404 Not Found"` - Patient not found
- `"Error: Invalid file type"` - Wrong file format (for file uploads)

## Future Enhancements

1. **Caching**: Add Hive caching for offline access
2. **Pagination**: Implement pagination for large datasets
3. **Real-time Updates**: Use WebSockets for live data
4. **Search**: Implement search functionality for medical history
5. **Export**: Add data export to PDF/CSV
