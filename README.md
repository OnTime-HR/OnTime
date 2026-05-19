# OnTime - Smart Attendance & HR Management

Welcome to the OnTime project! This is a robust Flutter application designed for modern HR and attendance management. This repository serves as the complete mobile solution for employee tracking, leave management, and role-based administration, leveraging the power of Firebase for real-time data synchronization and secure authentication. Below, you'll find a comprehensive guide to the features and setup instructions to get the application up and running.

🔗 Features
-----------------------

1. **Role-Based Access Control (RBAC)**
   * Distinct, unified dashboards for both **Employees** and **Managers**. The app automatically routes users to their specific interface upon secure login.

2. **Smart Attendance & GPS Tracking**
   * Real-time employee check-in and check-out tracking utilizing device geolocation to ensure accurate attendance logging.

3. **Leave & Medical Claim Management**
   * **Employees:** Can easily apply for various leave types (Annual, Sick, Casual) using interactive date pickers, and upload medical claim documents.
   * **Managers:** Have access to a dedicated approval screen to review, approve, or reject pending team requests with live Firestore updates.

4. **Secure OTP Authentication & Invite System**
   * Passwordless, phone number-based OTP login. Includes a secure backend invite system where managers assign employees via phone number to build their team structures dynamically.

5. **Real-time Database & Storage**
   * Fully integrated with Firebase Firestore for live data streams (company news, team stats, pending approvals) and Firebase Storage for handling document/image uploads.


🚀 Getting Started
-----------------------

To run the application locally, follow these steps:

### 1. Prerequisites & Versioning

* **Flutter Version:** This project uses Flutter version 3.41.6. 
* Make sure your environment is configured for this version to prevent package conflicts. If you use FVM (Flutter Version Management), set your version using:
  ```bash
  fvm use 3.41.6
