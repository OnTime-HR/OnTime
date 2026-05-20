# OnTime - Smart Attendance & HR Management

Welcome to the OnTime project! This is a robust Flutter application designed for modern HR and attendance management. This repository serves as the complete mobile solution for employee tracking, leave management, and role-based administration, leveraging the power of Firebase for real-time data synchronization and secure authentication. Below, you'll find a comprehensive guide to the features and setup instructions to get your application up and running.

## Features

1. **Role-Based Access Control (RBAC)**
   * Distinct, unified dashboards for both Employees and Managers. The app automatically routes users to their specific interface upon secure login.

2. **Smart Attendance & GPS Tracking**
   * Real-time employee check-in and check-out tracking utilizing device geolocation to ensure accurate attendance logging.

3. **Leave & Medical Claim Management**
   * **Employees:** Can easily apply for various leave types (Annual, Sick, Casual) using interactive date pickers, and upload medical claim documents.
   * **Managers:** Have access to a dedicated approval screen to review, approve, or reject pending team requests with live Firestore updates.

4. **Secure OTP Authentication & Invite System**
   * Passwordless, phone number-based OTP login. Includes a secure backend invite system where managers assign employees via phone number to build their team structures dynamically.

5. **Real-time Database & Storage**
   * Fully integrated with Firebase Firestore for live data streams (company news, team stats, pending approvals) and Firebase Storage for handling document/image uploads.

## Getting Started

To run the application, follow these steps:

1. **Install FVM**
   * FVM (Flutter Version Management) is highly recommended for managing Flutter versions. Install it from the terminal:
     ```bash
     dart pub global activate fvm
     ```

2. **Use Specific Flutter Version**
   * Set the exact Flutter version for this project to avoid package conflicts:
     ```bash
     fvm use 3.41.6
     ```

3. **Firebase Configuration**
   * Because this app relies heavily on Firebase Auth, Firestore, and Storage, you must include your Firebase configuration files before running:
     * **Android:** Place your `google-services.json` file in the `android/app/` directory.
     * **iOS:** Place your `GoogleService-Info.plist` file in the `ios/Runner/` directory.

4. **Install Dependencies**
   * Fetch all the required packages (`geolocator`, `image_picker`, `intl`, `firebase_core`, etc.) by running:
     ```bash
     fvm flutter pub get
     ```

5. **Running the Application**
   * Connect a physical device or start an emulator, then run the app using the following command:
     ```bash
     fvm flutter run
     ```

## Contributing

We welcome contributions to enhance this project. If you have suggestions or improvements, please create an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---
Thank you for exploring the OnTime project! We hope this application helps you streamline HR and attendance management. Happy coding!
