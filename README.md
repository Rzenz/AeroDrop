# AeroDrop: A UCLM Drone Delivery System

AeroDrop is a capstone project developed by Bachelor of Science in Information Technology students from the University of Cebu Lapu-Lapu and Mandaue. It is a campus-based marketplace and drone delivery application designed to manage the ordering and delivery of small items within the university.

The system connects campus users with approved campus vendors. Users can browse products, add items to their cart, place orders, select a delivery location, track the simulated drone, receive notifications, and view their order history. Vendors can manage products, inventory, and customer orders. Administrators can manage accounts, vendor applications, drones, deliveries, weather conditions, no-fly zones, reports, and system records.

AeroDrop currently uses simulated drone movement, telemetry, weather, payment, and notification workflows. It does not yet control physical drone hardware.

## Project Purpose

The purpose of AeroDrop is to provide a smart and organized campus delivery system for UCLM. It aims to improve how students, faculty, and staff order and receive small items from campus vendors through a centralized mobile application and a simulated drone delivery process.

The system focuses on:

* Campus-based product ordering
* Vendor and inventory management
* Order verification and preparation
* Drone delivery assignment
* Weather-aware delivery decisions
* Simulated real-time drone tracking
* User notifications
* Administrative monitoring and reporting

## Account Types

AeroDrop supports three main account roles:

### User

Users may be students, faculty members, or staff members who browse products and place delivery orders.

### Vendor

Vendors are approved campus stores or sellers that manage products, inventory, and customer orders.

### Admin

Administrators manage accounts, vendor applications, drones, deliveries, weather simulations, reports, and other system records.

## Key Features

### User Side

* User registration and login
* Per-login phone security verification
* User profile and profile-picture management
* Browse approved campus vendors
* Browse available products
* Search and view product information
* Add, update, and remove cart items
* Place campus delivery orders
* Select a campus delivery location
* View estimated order totals
* View order status and delivery progress
* Simulated real-time drone tracking
* View order and delivery history
* Cancel eligible pending orders
* Receive system and delivery notifications
* View unread notification count
* Simulate Safe, Caution, and Grounded weather conditions
* Pull-to-refresh support

### Vendor Side

* Vendor registration and application
* Admin approval before accessing the Vendor Dashboard
* Vendor business profile management
* Business logo and profile-image upload
* Predefined and custom store categories
* Add, view, edit, and deactivate products
* Manage product price, weight, and stock quantity
* View incoming customer orders
* Confirm or reject eligible orders
* Mark orders as preparing
* Mark prepared orders as ready for drone delivery
* Automatic inventory updates based on completed orders
* View vendor notifications
* View order and sales information

### Admin Side

* Secure admin login and phone verification
* View-only administrator account details
* View and manage registered accounts
* View user and vendor information
* Approve or reject vendor applications
* Suspend or reactivate eligible accounts
* View and manage orders and deliveries
* Monitor drone availability, battery, and status
* Assign drones to eligible deliveries
* View simulated drone telemetry
* Manage campus weather-safety status
* Manage no-fly-zone records
* View delivery status logs
* View reports and system analytics
* Monitor pending vendor applications and deliveries
* Pull-to-refresh support

## Ordering and Delivery Workflow

The main AeroDrop workflow is:

1. A user logs in and completes phone security verification.
2. The user browses approved vendors and available products.
3. The user adds products to the cart.
4. The user selects a campus delivery location and places an order.
5. The vendor reviews and confirms the order.
6. The vendor prepares the products.
7. The vendor marks the order as ready for delivery.
8. The system verifies:

   * Product availability
   * Package weight
   * Drone availability
   * Drone battery level
   * Campus pickup and drop-off locations
   * Current simulated weather condition
9. An available drone is assigned to the delivery.
10. The drone is simulated travelling to the vendor pickup location.
11. The system records package pickup.
12. The drone is simulated travelling from the vendor to the user.
13. The user views the drone’s simulated position and delivery progress.
14. The delivery is marked as completed.
15. The order, telemetry, notifications, and delivery logs remain available for history and reporting.

## Drone Setup

The prototype currently uses one primary simulated drone:

* **Drone Code:** DRN-001
* **Drone Name:** AeroCarrier Alpha
* **Model:** 001
* **Maximum Payload:** 0.5 kg
* **Minimum Battery Requirement:** At least 10% before delivery assignment
* **Telemetry:** Simulated
* **Position Tracking:** Simulated
* **Flight Movement:** Simulated

Supported drone statuses include:

* Available
* Assigned
* Busy
* Charging
* Maintenance
* Offline

## Weather Safety Simulation

AeroDrop includes a prototype weather-safety feature that affects drone delivery operations.

Available weather states are:

* **Safe** – Clear weather suitable for drone delivery
* **Caution** – Strong winds that may delay delivery
* **Grounded** – Heavy rain or unsafe weather that blocks drone dispatch

The selected condition is stored in Supabase and used by the order-readiness and drone-dispatch workflow.

This feature is a simulation and is not connected to a live external weather service.

## Campus Locations

AeroDrop is intended for use within the University of Cebu Lapu-Lapu and Mandaue campus.

Supported campus locations include:

* Old Building or Main Building
* Annex 1 Building
* Annex 2 Building
* Basic Education Building
* Maritime Building

These locations are used for vendor pickup and user delivery destinations.

## Technology Stack

### Mobile Application

* Flutter
* Dart
* Riverpod
* GoRouter
* Material Design

### Backend Services

* Supabase Authentication
* Supabase PostgreSQL Database
* Supabase Storage
* Supabase Realtime
* PostgreSQL functions and triggers
* Row-Level Security policies

### Development and Version Control

* Git
* GitHub
* Android Studio
* Visual Studio Code
* Figma

## Database Structure

AeroDrop uses Supabase as its backend platform.

The simplified database includes:

* `users`
* `campus_locations`
* `products`
* `orders`
* `order_items`
* `drones`
* `deliveries`
* `drone_telemetry`
* `notifications`
* `weather_safety`
* `no_fly_zones`
* `delivery_status_logs`

Supabase Auth manages:

* Email authentication
* Password authentication
* User sessions

The `public.users` table manages:

* User profile information
* Account role
* Account status
* Vendor application status
* Business information
* Profile and business-logo URLs

## Security Features

* Supabase Authentication
* Role-based access for User, Vendor, and Admin accounts
* Row-Level Security policies
* Secure PostgreSQL functions
* Per-login phone security verification
* Account-status validation
* Vendor-approval checks
* Protected product, order, delivery, and profile records
* Session cleanup during logout
* Authentication checks before protected database queries

The Supabase service-role key is not stored in the Flutter application.

## Main Transaction CRUD

The main transaction of AeroDrop is the product-order and drone-delivery process.

### Create

* Users create orders.
* Vendors create products.
* The system creates delivery, notification, telemetry, and status-log records.

### Read

* Users view vendors, products, orders, tracking, notifications, and history.
* Vendors view products, inventory, orders, and notifications.
* Administrators view accounts, applications, drones, deliveries, reports, and logs.

### Update

* Users update their cart, profile, and eligible orders.
* Vendors update products, stock, order status, and business information.
* Administrators update account status, vendor applications, drone status, weather safety, and delivery records.
* The system updates delivery progress and drone telemetry.

### Delete

The system generally uses deactivation, cancellation, or soft deletion instead of permanently removing important transaction records.

Cancelled and rejected records are retained for:

* History
* Accountability
* Reporting
* Administrative review

## System Modules

AeroDrop consists of the following major modules:

1. User Account Module
2. Vendor Account Module
3. Product Catalog Module
4. Inventory Management Module
5. Cart and Order Module
6. Order Verification Module
7. Drone Delivery Management Module
8. Tracking and Status Module
9. Notification Module
10. Admin Management Module
11. Reports and Logs Module

## Testing and Code Quality

The project includes:

* Flutter static analysis
* Unit and provider tests
* Supabase database integration testing
* Simplified-schema validation
* Authentication and routing validation
* Runtime testing on an Android device

Current development checks include:

```bash
flutter analyze
flutter test
```

The Supabase schema test can be executed using the required environment definitions.

## Team Members

This capstone project was developed by BSIT students from the University of Cebu Lapu-Lapu and Mandaue.

| Name                         | Role            |
| ---------------------------- | --------------- |
| Ardiente, Lurinylle Clark B. | Hacker          |
| Ogdol, Kim Andrie G.         | Project Manager |
| Oñada, Rozencrantz G.        | Hipster         |
| Tiu, Erickson N.             | Hacker          |

## Institution

**University of Cebu Lapu-Lapu and Mandaue**
Bachelor of Science in Information Technology

## Project Status

AeroDrop is currently a capstone prototype.

The following features are simulated:

* Drone flight and movement
* Drone telemetry
* GPS position updates
* Weather conditions
* Payment processing
* Delivery tracking
* Push-notification behavior

Future development may include:

* Physical drone integration
* Live GPS tracking
* Actual battery and sensor telemetry
* Obstacle-detection hardware
* Live weather-service integration
* Automated route optimization
* Geofencing and live no-fly-zone enforcement
* Real SMS verification
* Real payment-gateway integration
* Production push notifications
* Expanded campus-vendor support
