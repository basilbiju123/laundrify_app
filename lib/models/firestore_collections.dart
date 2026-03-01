// ════════════════════════════════════════════════════════════
// FIRESTORE COLLECTIONS SCHEMA
// ════════════════════════════════════════════════════════════
//
// Root Collections:
//   /users/{uid}                  → all user types (role field differentiates)
//   /orders/{orderId}             → all orders
//   /notifications/{notifId}      → broadcast notifications
//   /feedback/{feedbackId}        → customer feedback
//
// Sub-collections under /users/{uid}:
//   /addresses/{addrId}           → saved addresses
//   /coupons/{couponId}           → user coupons
//   /loyalty_history/{historyId}  → loyalty points history
//   /abandoned_carts/{cartId}     → incomplete/failed payments
//   /read_notifications/{notifId} → read receipt
//
// USER DOCUMENT FIELDS by role:
//
// ALL USERS:
//   uid, name, email, phone, role (user|admin|manager|delivery|staff)
//   isBlocked, isActive, createdAt, updatedAt
//   fcmToken, tokenUpdatedAt
//   loyaltyPoints, totalOrders, totalSpent
//   referralCode, referredBy
//   photoUrl, emailVerified, phoneVerified, authMethod
//
// DELIVERY AGENTS (role = 'delivery'):
//   isOnline (bool)               → whether agent is currently on shift
//   vehicleType                   → bike/car/scooter
//   vehicleNumber
//   deliveryStats: { totalDeliveries, completedToday, earnings, rating }
//
// EMPLOYEES / STAFF (role = 'staff'):
//   department                    → washing/ironing/packaging
//   shift                         → morning/evening/night
//   employeeId
//
// MANAGERS (role = 'manager'):
//   branchId
//   managedStaffCount
//
// ADMIN (role = 'admin'):
//   adminLevel                    → 1 (super) / 2 (regular)
//
// ORDER DOCUMENT FIELDS:
//   userId, customerName, customerEmail
//   items: [{itemName, serviceName, quantity, price}]
//   totalAmount, totalItems
//   status: pending|assigned|pickup|processing|ready|out_for_delivery|delivered|cancelled
//   paymentMethod: online|cod
//   paymentStatus: pending|paid|failed|refunded
//   pickupDate, pickupTime
//   assignedTo (uid of delivery agent)
//   assignedBy (uid of manager)
//   cancellationReason, cancelledBy, cancelledAt
//   refundAmount, refundStatus
//   statusHistory: [{status, timestamp, note, updatedBy}]
//   createdAt, updatedAt, deliveredAt
//
// ════════════════════════════════════════════════════════════

// This file is documentation-only. See firestore_service.dart for implementation.
