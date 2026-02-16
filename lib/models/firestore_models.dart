import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════
// USER MODEL (with Role Support)
// ══════════════════════════════════════════════════════════════

enum UserRole {
  user,
  admin,
  manager,
  delivery,
  staff,
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool isBlocked;
  final bool isActive;
  final DateTime? createdAt;
  final Map<String, dynamic>? location;
  final DeliveryData? deliveryData;
  final int totalOrders;
  final double totalSpent;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isBlocked = false,
    this.isActive = true,
    this.createdAt,
    this.location,
    this.deliveryData,
    this.totalOrders = 0,
    this.totalSpent = 0,
  });

  // Convert from Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: _parseRole(data['role'] ?? 'user'),
      isBlocked: data['isBlocked'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      location: data['location'] as Map<String, dynamic>?,
      deliveryData: data['deliveryData'] != null
          ? DeliveryData.fromMap(data['deliveryData'])
          : null,
      totalOrders: data['totalOrders'] ?? 0,
      totalSpent: (data['totalSpent'] ?? 0).toDouble(),
    );
  }

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'isBlocked': isBlocked,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'location': location,
      'deliveryData': deliveryData?.toMap(),
      'totalOrders': totalOrders,
      'totalSpent': totalSpent,
    };
  }

  static UserRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'delivery':
        return UserRole.delivery;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.user;
    }
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    bool? isBlocked,
    bool? isActive,
    Map<String, dynamic>? location,
    DeliveryData? deliveryData,
    int? totalOrders,
    double? totalSpent,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isBlocked: isBlocked ?? this.isBlocked,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      location: location ?? this.location,
      deliveryData: deliveryData ?? this.deliveryData,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DELIVERY DATA (for Delivery Partners)
// ══════════════════════════════════════════════════════════════

class DeliveryData {
  final String? vehicleNumber;
  final String? vehicleType;
  final bool isAvailable;
  final String? currentOrderId;
  final int totalDeliveries;
  final double totalEarnings;
  final double pendingEarnings;
  final DateTime? lastActiveAt;

  DeliveryData({
    this.vehicleNumber,
    this.vehicleType,
    this.isAvailable = true,
    this.currentOrderId,
    this.totalDeliveries = 0,
    this.totalEarnings = 0,
    this.pendingEarnings = 0,
    this.lastActiveAt,
  });

  factory DeliveryData.fromMap(Map<String, dynamic> map) {
    return DeliveryData(
      vehicleNumber: map['vehicleNumber'] as String?,
      vehicleType: map['vehicleType'] as String?,
      isAvailable: map['isAvailable'] ?? true,
      currentOrderId: map['currentOrderId'] as String?,
      totalDeliveries: map['totalDeliveries'] ?? 0,
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      pendingEarnings: (map['pendingEarnings'] ?? 0).toDouble(),
      lastActiveAt: (map['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'isAvailable': isAvailable,
      'currentOrderId': currentOrderId,
      'totalDeliveries': totalDeliveries,
      'totalEarnings': totalEarnings,
      'pendingEarnings': pendingEarnings,
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
    };
  }
}

// ══════════════════════════════════════════════════════════════
// ORDER MODEL (with Assignment Support)
// ══════════════════════════════════════════════════════════════

enum OrderStatus {
  pending,
  pickup,
  processing,
  delivery,
  completed,
  cancelled,
}

class OrderModel {
  final String orderId;
  final String userId;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final String? assignedTo; // Delivery partner UID
  final String? assignedBy; // Admin/Manager UID who assigned
  final DateTime? assignedAt;
  final DateTime? pickupDate;
  final DateTime? deliveryDate;
  final Map<String, dynamic>? address;
  final String? paymentStatus;
  final String? paymentId;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? notes;

  OrderModel({
    required this.orderId,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.assignedTo,
    this.assignedBy,
    this.assignedAt,
    this.pickupDate,
    this.deliveryDate,
    this.address,
    this.paymentStatus,
    this.paymentId,
    this.createdAt,
    this.completedAt,
    this.notes,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      orderId: doc.id,
      userId: data['userId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      status: _parseOrderStatus(data['status'] ?? 'pending'),
      assignedTo: data['assignedTo'] as String?,
      assignedBy: data['assignedBy'] as String?,
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      pickupDate: (data['pickupDate'] as Timestamp?)?.toDate(),
      deliveryDate: (data['deliveryDate'] as Timestamp?)?.toDate(),
      address: data['address'] as Map<String, dynamic>?,
      paymentStatus: data['paymentStatus'] as String?,
      paymentId: data['paymentId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status.name,
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'pickupDate': pickupDate != null ? Timestamp.fromDate(pickupDate!) : null,
      'deliveryDate': deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null,
      'address': address,
      'paymentStatus': paymentStatus,
      'paymentId': paymentId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notes': notes,
    };
  }

  static OrderStatus _parseOrderStatus(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'pickup':
        return OrderStatus.pickup;
      case 'processing':
        return OrderStatus.processing;
      case 'delivery':
        return OrderStatus.delivery;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  OrderModel copyWith({
    OrderStatus? status,
    String? assignedTo,
    String? assignedBy,
    DateTime? assignedAt,
    DateTime? pickupDate,
    DateTime? deliveryDate,
    String? paymentStatus,
    String? paymentId,
    DateTime? completedAt,
    String? notes,
  }) {
    return OrderModel(
      orderId: orderId,
      userId: userId,
      items: items,
      totalAmount: totalAmount,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      pickupDate: pickupDate ?? this.pickupDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      address: address,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ORDER ITEM
// ══════════════════════════════════════════════════════════════

class OrderItem {
  final String itemId;
  final String itemName;
  final String serviceId;
  final String serviceName;
  final int quantity;
  final double price;

  OrderItem({
    required this.itemId,
    required this.itemName,
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'quantity': quantity,
      'price': price,
    };
  }
}

// ══════════════════════════════════════════════════════════════
// SERVICE MODEL
// ══════════════════════════════════════════════════════════════

class ServiceModel {
  final String serviceId;
  final String title;
  final String? image;
  final String? color;
  final bool isActive;
  final int sortOrder;

  ServiceModel({
    required this.serviceId,
    required this.title,
    this.image,
    this.color,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceModel(
      serviceId: doc.id,
      title: data['title'] ?? '',
      image: data['image'] as String?,
      color: data['color'] as String?,
      isActive: data['isActive'] ?? true,
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'image': image,
      'color': color,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }
}

// ══════════════════════════════════════════════════════════════
// SERVICE ITEM MODEL
// ══════════════════════════════════════════════════════════════

class ServiceItemModel {
  final String itemId;
  final String serviceId;
  final String itemName;
  final double price;
  final bool isAvailable;

  ServiceItemModel({
    required this.itemId,
    required this.serviceId,
    required this.itemName,
    required this.price,
    this.isAvailable = true,
  });

  factory ServiceItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceItemModel(
      itemId: doc.id,
      serviceId: data['serviceId'] ?? '',
      itemName: data['itemName'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'serviceId': serviceId,
      'itemName': itemName,
      'price': price,
      'isAvailable': isAvailable,
    };
  }
}
