// lib/models/timesheet_data.dart

class TimesheetData {
  // Campos de NewTimeSheet
  String jobName;
  String date;
  String tm; // Territorial Manager
  String jobSize;
  String material;
  String jobDesc;
  String foreman;
  String vehicle;

  // Novo campo
  String notes;

  // Lista de workers
  List<Map<String, String>> workers;

  TimesheetData({
    this.jobName = '',
    this.date = '',
    this.tm = '',
    this.jobSize = '',
    this.material = '',
    this.jobDesc = '',
    this.foreman = '',
    this.vehicle = '',
    this.notes = '', // <-- Novo
    List<Map<String, String>>? workers,
  }) : workers = workers ?? [];
}
