import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<InvoiceModel>> getInvoicesStream() {
    final String? uid = _uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return _db
        .collection('invoices')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(InvoiceModel.fromFirestore)
              .toList()
            ..sort((a, b) {
              final DateTime aDate = a.issuedAt ?? a.createdAt ?? DateTime(1970);
              final DateTime bDate = b.issuedAt ?? b.createdAt ?? DateTime(1970);
              return bDate.compareTo(aDate);
            }),
        );
  }

  Future<void> addInvoice(Map<String, dynamic> data) async {
    final String? uid = _uid;
    if (uid == null) {
      throw Exception('User not logged in.');
    }

    final DocumentReference<Map<String, dynamic>> ref = _db.collection('invoices').doc();
    await ref.set(
      <String, dynamic>{
        ...data,
        'ownerId': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

class InvoiceModel {
  InvoiceModel({
    required this.id,
    required this.ownerId,
    required this.amount,
    required this.title,
    required this.vendor,
    this.issuedAt,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final double amount;
  final String title;
  final String vendor;
  final DateTime? issuedAt;
  final DateTime? createdAt;

  factory InvoiceModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    return InvoiceModel(
      id: doc.id,
      ownerId: (data['ownerId'] as String? ?? '').trim(),
      amount: _toDouble(data['amount']),
      title: (data['title'] as String? ?? '').trim(),
      vendor: (data['vendor'] as String? ?? '').trim(),
      issuedAt: _toDate(data['issuedAt']),
      createdAt: _toDate(data['createdAt']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
