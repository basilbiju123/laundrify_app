// ════════════════════════════════════════════════════════════
// FIRESTORE COLLECTIONS SCHEMA
// ════════════════════════════════════════════════════════════
//
// ┌──────────────────────────────────────────────────────────────┐
// │  WHO GOES WHERE                                              │
// ├──────────────────────────────────────────────────────────────┤
// │  /users/{uid}            → CUSTOMERS ONLY  (role = 'user')  │
// │                            People using the laundry app      │
// │                                                              │
// │  /managers/{uid}         → Managers        (role = 'manager')│
// │  /delivery_agents/{uid}  → Delivery boys   (role = 'delivery')│
// │  /staff/{uid}            → Staff members   (role = 'staff') │
// │                                                              │
// │  Admin accounts are managed separately — not in /users.      │
// │                                                              │
// │  /orders/{orderId}       → all orders                        │
// │  /notifications/{id}     → broadcast notifications           │
// │  /feedback/{id}          → customer feedback                 │
// └──────────────────────────────────────────────────────────────┘
//
// ── RULE: /users IS CUSTOMERS ONLY ──────────────────────────────
//
//  The /users collection is ONLY for people using the customer-
//  facing dashboard (DashboardPage). It is what the admin sees
//  in "User Management". Employees (managers, delivery, staff)
//  are NEVER stored in /users — they live in their own collections.
//
// ── HOW SIGN-IN ROUTING WORKS ───────────────────────────────────
//
//  RoleBasedAuthService.handleGoogleSignIn() runs after every
//  Google sign-in and checks in this order:
//
//  1. Does /users/{uid} exist?
//     → YES: read role, return correct dashboard route
//
//  2. Is this email in /users where createdByAdmin == true?
//     → YES: merge doc to real uid, route to pre-assigned role
//
//  3. Is this email in /managers, /delivery_agents, or /staff?
//     → YES: migrate doc to real uid, write to /users with
//            correct role (NOT 'user'), route to role dashboard
//
//  4. None of the above → brand new customer:
//     → Write to /users with role='user', route to /dashboard
//
//  This guarantees:
//    • A manager emailed by admin → signs in → goes to ManagerDashboard
//    • A delivery boy → signs in → goes to DeliveryDashboard
//    • A regular customer → signs in → goes to DashboardPage
//    • /users only ever contains role='user' documents
//
// ── ADMIN PANEL PAGES ───────────────────────────────────────────
//
//  "User Management"     → queries /users  (role == 'user' only)
//  "Employee Management" → queries /delivery_agents | /managers | /staff
//                          (or /users where role in [...] for "All" view)
//
// ════════════════════════════════════════════════════════════
// FIELD SCHEMAS
// ════════════════════════════════════════════════════════════
//
// /users/{uid}  — CUSTOMERS ONLY:
//   uid, name, email, phone, role='user'
//   isBlocked, isActive
//   photoURL, authMethod, emailVerified
//   loyaltyPoints, totalOrders, totalSpent
//   referralCode, referredBy
//   location: { latitude, longitude, address }
//   fcmToken, tokenUpdatedAt
//   createdAt, updatedAt, lastSignIn
//
// /managers/{uid}:
//   uid, name, email, phone, role='manager'
//   isActive, isBlocked, employeeId, shift
//   branchId, managedStaffCount
//   activeOrders, completedOrders, rating
//   photoURL, createdAt, updatedAt, syncedAt
//
// /delivery_agents/{uid}:
//   uid, name, email, phone, role='delivery'
//   isActive, isBlocked, isOnline, employeeId, shift
//   vehicleType, vehicleNumber
//   totalDeliveries, totalEarnings, pendingEarnings
//   activeOrders, completedOrders, rating
//   photoURL, createdAt, updatedAt, syncedAt
//
// /staff/{uid}:
//   uid, name, email, phone, role='staff'
//   isActive, isBlocked, employeeId, shift, department
//   activeOrders, completedOrders, rating
//   photoURL, createdAt, updatedAt, syncedAt
//
// /orders/{orderId}:
//   userId (customer uid), customerName, customerEmail
//   items: [{ itemName, serviceName, quantity, price }]
//   totalAmount, totalItems
//   status: pending|assigned|pickup|processing|ready
//          |out_for_delivery|delivered|cancelled
//   paymentMethod: online|cod
//   paymentStatus: pending|paid|failed|refunded
//   pickupDate, pickupTime
//   assignedTo  (uid from /delivery_agents)
//   assignedBy  (uid from /managers or admin)
//   cancellationReason, cancelledBy, cancelledAt
//   refundAmount, refundStatus
//   statusHistory: [{ status, timestamp, note, updatedBy }]
//   createdAt, updatedAt, deliveredAt
//
// ════════════════════════════════════════════════════════════

// Documentation only — see role_based_auth_service.dart
