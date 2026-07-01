# AeroDrop: UCLM Drone Delivery System

AeroDrop is a capstone project developed by BSIT students from the University of Cebu Lapu-Lapu and Mandaue. It is a campus-based drone delivery application designed to help manage small-item deliveries within the school using a simulated drone delivery workflow.

The system allows users to create delivery requests, select campus pickup and drop-off locations, track delivery status, receive notifications, and view delivery history. The admin side can manage users, drones, delivery approvals, and delivery status updates.

## Project Purpose

The purpose of AeroDrop is to provide a smart and organized delivery system for campus logistics. It focuses on improving the process of sending small items between selected school buildings by using a drone-based delivery concept.

## Key Features

### User Side

* User registration and login
* Campus-only pickup and drop-off selection
* Package weight validation
* Maximum payload limit of 0.5 kg
* Distance-based payment estimation
* Delivery request submission
* Delivery status tracking
* Delivery history
* Delivery cancellation for pending requests
* Notification system with unread badge count
* Pull-to-refresh support

### Admin Side

* Admin login
* View users from the database
* View and manage delivery requests
* Accept or reject pending deliveries
* Manage drone information
* Recharge drone battery
* Notification badge for pending deliveries
* Pull-to-refresh support

## Drone Setup

The system uses one drone for the prototype:

* Drone Name: AeroCarrier Alpha
* Model Type: 001
* Maximum Payload: 0.5 kg
* Battery Requirement: At least 10% battery before accepting a delivery
* Status: Available, Busy, Maintenance, or Offline

## Campus Locations

The system is designed for campus use only. The available pickup and drop-off locations are:

* Old Building (Main Building)
* Annex 1 Building
* Annex 2 Building
* Basic Education Building (Basic Ed Building)
* Maritime Building

## Technology Stack

* Flutter
* Dart
* Riverpod
* GoRouter
* Supabase
* PostgreSQL

## Database Features

The system uses Supabase as the backend database. It stores and manages:

* Users
* Deliveries
* Drones
* Payments
* Notifications
* Delivery status logs
* Campus locations
* Drone telemetry
* Weather safety data

## Main Transaction CRUD

The main transaction of the system is the delivery request.

* Create: User creates a delivery request
* Read: User and admin view delivery details, tracking, and history
* Update: Admin accepts or rejects delivery requests, and delivery status updates
* Delete: User cancels a pending delivery request using soft delete

The system does not permanently delete delivery records. Cancelled requests are kept in the database for history and accountability.

## Team Members

This capstone project was developed by BSIT students from the University of Cebu Lapu-Lapu and Mandaue.

| Name                         | Role            |
| ---------------------------- | --------------- |
| Ardiente, Lurinylle Clark B. | Hacker          |
| Ogdol, Kim Andrie G.         | Project Manager |
| Oñada, Rozencrantz G.        | Hipster         |
| Tiu, Erickson N.             | Hacker          |

## Institution

University of Cebu Lapu-Lapu and Mandaue
Bachelor of Science in Information Technology

## Project Status

AeroDrop is a capstone prototype. The system uses simulated drone delivery, payment, tracking, and notification workflows. Future improvements may include real drone hardware integration, live battery telemetry, GPS-based tracking, and real payment gateway integration.
