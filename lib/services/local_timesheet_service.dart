import 'dart:convert'; // <-- para jsonEncode/jsonDecode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'local_timesheet_service.g.dart';

@HiveType(typeId: 0)
class LocalTimesheet extends HiveObject {
  @HiveField(0)
  String docId;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String jobName;

  @HiveField(3)
  String tm;

  @HiveField(4)
  String material;

  @HiveField(5)
  DateTime date;

  @HiveField(6)
  DateTime updatedAt;

  // Campos extras
  @HiveField(7)
  String jobSize;

  @HiveField(8)
  String jobDesc;

  @HiveField(9)
  String foreman;

  @HiveField(10)
  String vehicle;

  @HiveField(11)
  String notes;

  // Armazenamos a lista de workers em JSON
  @HiveField(12)
  String workersJson;

  LocalTimesheet({
    required this.docId,
    required this.userId,
    required this.jobName,
    required this.tm,
    required this.material,
    required this.date,
    required this.updatedAt,
    this.jobSize = '',
    this.jobDesc = '',
    this.foreman = '',
    this.vehicle = '',
    this.notes = '',
    this.workersJson = '[]',
  });

  /// Getter que decodifica o 'workersJson' e retorna uma lista de mapas
  List<Map<String, dynamic>> get workers {
    try {
      final decoded = jsonDecode(workersJson);
      if (decoded is List) {
        return decoded
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

class LocalTimesheetService {
  static const String boxName = 'local_timesheets';

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LocalTimesheetAdapter());
    }
    await Hive.openBox<LocalTimesheet>(boxName);
  }

  static Box<LocalTimesheet> get box => Hive.box<LocalTimesheet>(boxName);

  static List<LocalTimesheet> getAllTimesheets() {
    return box.values.toList();
  }

  static Future<void> saveOrUpdate(LocalTimesheet item) async {
    final existingKey = box.keys.firstWhere(
      (k) => box.get(k)?.docId == item.docId,
      orElse: () => null,
    );
    if (existingKey != null) {
      await box.put(existingKey, item);
    } else {
      await box.add(item);
    }
  }

  static Future<void> syncWithFirestore() async {
    final snap = await FirebaseFirestore.instance
        .collection('timesheets')
        .get();

    for (var doc in snap.docs) {
      final data = doc.data();

      final item = LocalTimesheet(
        docId: doc.id,
        userId: data['userId'] ?? '',
        jobName: data['jobName'] ?? '',
        tm: data['tm'] ?? '',
        material: data['material'] ?? '',
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

        jobSize: data['jobSize'] ?? '',
        jobDesc: data['jobDesc'] ?? '',
        foreman: data['foreman'] ?? '',
        vehicle: data['vehicle'] ?? '',
        notes: data['notes'] ?? '',
        // Convertendo a lista de workers em JSON
        workersJson: data['workers'] != null
            ? jsonEncode(data['workers'])
            : '[]',
      );

      await saveOrUpdate(item);
    }
  }
}
