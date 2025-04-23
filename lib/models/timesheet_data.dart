class TimesheetData {
  String jobName;
  DateTime? date;  // <--- Agora é DateTime (pode ser nulo).
  String tm;
  String jobSize;
  String material;
  String jobDesc;
  String foreman;
  String vehicle;
  String notes;
  List<Map<String, String>> workers;
  String userId;

  TimesheetData({
    this.jobName = '',
    this.date, // sem default, inicia nulo
    this.tm = '',
    this.jobSize = '',
    this.material = '',
    this.jobDesc = '',
    this.foreman = '',
    this.vehicle = '',
    this.notes = '',
    List<Map<String, String>>? workers,
    this.userId = '',
  }) : workers = workers ?? [];
}
