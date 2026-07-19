import 'package:flutter/material.dart';

class MockVendor {
  final String id;
  final String businessName;
  final String ownerName;
  final String email;
  final String phone;
  final String building;
  final String description;
  final Color logoColor;
  final String logoInitials;
  final bool isOpen;
  final bool isActive;
  final List<String> categories;
  final double rating;
  final int totalOrders;

  const MockVendor({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.building,
    required this.description,
    required this.logoColor,
    required this.logoInitials,
    required this.isOpen,
    required this.isActive,
    required this.categories,
    required this.rating,
    required this.totalOrders,
  });
}

final List<MockVendor> mockVendors = [
  MockVendor(
    id: 'v-001',
    businessName: 'Campus Bites',
    ownerName: 'Maria Santos',
    email: 'campusbites@gmail.com',
    phone: '09171234567',
    building: 'Old Building – Ground Floor',
    description:
        'Your go-to campus canteen for hot meals, snacks, and refreshments. Fresh food prepared daily for students and faculty.',
    logoColor: const Color(0xFFFF6B35),
    logoInitials: 'CB',
    isOpen: true,
    isActive: true,
    categories: ['Food', 'Drinks', 'Snacks'],
    rating: 4.7,
    totalOrders: 342,
  ),
  MockVendor(
    id: 'v-002',
    businessName: 'TechZone Supplies',
    ownerName: 'Jose Cruz',
    email: 'techzone@gmail.com',
    phone: '09182345678',
    building: 'Annex 1 – Room 102',
    description:
        'Electronic accessories, stationery, and tech gadgets for students. USB cables, earphones, notebooks, and more.',
    logoColor: const Color(0xFF1976D2),
    logoInitials: 'TZ',
    isOpen: true,
    isActive: true,
    categories: ['Electronics', 'Stationery', 'Accessories'],
    rating: 4.5,
    totalOrders: 198,
  ),
  MockVendor(
    id: 'v-003',
    businessName: 'Book Nook',
    ownerName: 'Ana Reyes',
    email: 'booknook@gmail.com',
    phone: '09193456789',
    building: 'Library Building – 1st Floor',
    description:
        'Academic books, reviewers, and school supplies. Serving UCLM students with all their reading and study needs.',
    logoColor: const Color(0xFF7B1FA2),
    logoInitials: 'BN',
    isOpen: true,
    isActive: true,
    categories: ['Books', 'Stationery', 'Reviewers'],
    rating: 4.8,
    totalOrders: 521,
  ),
  MockVendor(
    id: 'v-004',
    businessName: 'Merienda Hub',
    ownerName: 'Carlo Dela Cruz',
    email: 'meriendahub@gmail.com',
    phone: '09204567890',
    building: 'Annex 2 – Canteen Area',
    description:
        'Affordable merienda, rice meals, and cold beverages. Quick bites perfect for busy students between classes.',
    logoColor: const Color(0xFF00897B),
    logoInitials: 'MH',
    isOpen: false,
    isActive: true,
    categories: ['Food', 'Drinks', 'Rice Meals'],
    rating: 4.3,
    totalOrders: 267,
  ),
  MockVendor(
    id: 'v-005',
    businessName: 'Maritime Mart',
    ownerName: 'Paolo Bautista',
    email: 'maritimemart@gmail.com',
    phone: '09215678901',
    building: 'Maritime Building – Lobby',
    description:
        'Specialized supplies for maritime students: nautical instruments, safety equipment, and uniforms.',
    logoColor: const Color(0xFF0277BD),
    logoInitials: 'MM',
    isOpen: true,
    isActive: true,
    categories: ['Maritime Supplies', 'Uniforms', 'Equipment'],
    rating: 4.6,
    totalOrders: 89,
  ),
  MockVendor(
    id: 'v-006',
    businessName: 'Healthy Corner',
    ownerName: 'Liza Gonzales',
    email: 'healthycorner@gmail.com',
    phone: '09226789012',
    building: 'Basic Education Building – Canteen',
    description:
        'Healthy food options including fresh juices, salads, and organic snacks. Fuel your studies the right way.',
    logoColor: const Color(0xFF388E3C),
    logoInitials: 'HC',
    isOpen: true,
    isActive: true,
    categories: ['Healthy Food', 'Juices', 'Organic'],
    rating: 4.4,
    totalOrders: 156,
  ),
];
