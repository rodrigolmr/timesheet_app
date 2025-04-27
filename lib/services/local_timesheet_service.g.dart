// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_timesheet_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalTimesheetAdapter extends TypeAdapter<LocalTimesheet> {
  @override
  final int typeId = 0;

  @override
  LocalTimesheet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalTimesheet(
      docId: fields[0] as String,
      userId: fields[1] as String,
      jobName: fields[2] as String,
      tm: fields[3] as String,
      material: fields[4] as String,
      date: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      jobSize: fields[7] as String,
      jobDesc: fields[8] as String,
      foreman: fields[9] as String,
      vehicle: fields[10] as String,
      notes: fields[11] as String,
      workersJson: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, LocalTimesheet obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.docId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.jobName)
      ..writeByte(3)
      ..write(obj.tm)
      ..writeByte(4)
      ..write(obj.material)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.jobSize)
      ..writeByte(8)
      ..write(obj.jobDesc)
      ..writeByte(9)
      ..write(obj.foreman)
      ..writeByte(10)
      ..write(obj.vehicle)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.workersJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalTimesheetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
