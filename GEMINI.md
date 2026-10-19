# Smart Entry — Flutter Desktop

Dart 3 | Flutter | Supabase | Windows Desktop | Node.js (WhatsApp Server)

## Structure

```text
lib/
├── core/
│   ├── billing/          # PDF generation, printing services, and invoice logic
│   ├── credit_limit/     # Credit limit calculations and rules
│   ├── customer/         # Customer CRUD and list management
│   ├── entries/          # Daily tea collection entry forms and lists
│   ├── network_service.dart # Internet connection monitoring and alerts
│   ├── theme.dart        # App-wide UI theme configuration
│   ├── app_state.dart    # Global state (e.g., Organization ID, username)
│   └── widgets/          # Reusable UI components (loaders, dialogs, etc.)
├── features/
│   ├── auth/             # Login screen and user session handling
│   ├── dashboard/        # Main dashboard, charts, and analysis screens
│   ├── reports/          # Monthly closings and reporting logic
│   ├── settings/         # App settings and configurations
│   └── splash/           # Splash screen and initialization logic
├── main.dart             # App entry point, Supabase init, Window manager setup
whatsapp_server/
├── server.js             # Express/Socket.io backend for WhatsApp messaging via Puppeteer
├── package.json
pubspec.yaml              # Dependencies (supabase_flutter, printing, pdf, fl_chart, etc.)
```

## Setup

```bash
# Install Flutter dependencies
flutter pub get

# Install Node.js dependencies for the WhatsApp server
cd whatsapp_server
npm install
```

## Running Locally

```bash
# Run the Flutter app on Windows
flutter run -d windows
```
*(The WhatsApp Node.js server is automatically launched in the background by `main.dart` during startup).*

## Testing & Linting

```bash
flutter analyze     # Linting and static analysis
flutter test        # Run unit tests
```

## Code Style & Guidelines

- **Code Comments**: Do not put Sinhala inside comments. All comments must be written in English.
- **Deprecations**: Use `withValues()` instead of the deprecated `withOpacity()`. Use `initialValue` instead of `value` where applicable in form fields.
- **Logging**: Avoid using `print()` in production code. Use `debugPrint()` or a dedicated logging framework.
- **Null Safety**: Strictly adhere to Dart sound null safety.
- **Input Validation**: For numerical inputs (e.g., TextFields), enforce that they only accept numbers with up to two decimal points (using `FilteringTextInputFormatter`).

## Key Patterns

### Supabase Integration (Tenant Isolation)
CRITICAL RULE: The app serves multiple independent organizations. You MUST ALWAYS use `AppState.currentOrganizationId` (or `organization_id`) when querying, inserting, or updating the database. 
Another organization's details MUST NEVER appear in a different organization's workspace. Failure to include `.eq('organization_id', orgId)` in queries will result in severe data leakage across tenants.

### Window Management
The app uses `window_manager` to configure the desktop window size (1280x720) and properties. Ensure UI remains responsive but is optimized for desktop interaction.

### WhatsApp Node.js Server
A local Node.js server (`whatsapp_server/server.js`) runs alongside the Flutter app. It uses `whatsapp-web.js` (Puppeteer) to connect to WhatsApp Web. The Flutter app communicates with this server via Socket.io to send batch PDF invoices and messages. 

### Printing & PDF Generation
Invoices and reports are generated using the `pdf` package and sent to physical printers using the `printing` package. Keep PDF layouts modularized within `lib/core/billing/`.

## Deployment

The app is packaged as a Windows MSIX installer using the `msix` package configured in `pubspec.yaml`.

```bash
# Build the executable
flutter build windows

# Create the MSIX installer
flutter pub run msix:create
```
