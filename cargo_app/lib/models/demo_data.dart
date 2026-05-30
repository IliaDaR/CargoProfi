import '../models/trip.dart';
import '../models/expense.dart';
import '../models/vehicle.dart';
import '../models/salary_rule.dart';
import '../models/salary_payment.dart';
import '../utils/constants.dart';

/// Демо-данные для тестирования интерфейса без Firebase.
class DemoData {
  static final now = DateTime.now();

  static final List<Vehicle> vehicles = [
    Vehicle(
      id: 'v1', ownerId: 'demo-uid', plateNumber: 'А123ВС 177',
      brand: 'MAN', model: 'TGX', year: 2020, fuelType: 'diesel',
      createdAt: now.subtract(const Duration(days: 365)),
      isActive: true, activeDriverId: 'd1',
    ),
    Vehicle(
      id: 'v2', ownerId: 'demo-uid', plateNumber: 'В456КМ 77',
      brand: 'Volvo', model: 'FH16', year: 2021, fuelType: 'diesel',
      createdAt: now.subtract(const Duration(days: 200)),
      isActive: false,
    ),
    Vehicle(
      id: 'v3', ownerId: 'demo-uid', plateNumber: 'Е789ОР 178',
      brand: 'Scania', model: 'R500', year: 2019, fuelType: 'diesel',
      createdAt: now.subtract(const Duration(days: 500)),
      isActive: true, activeDriverId: 'd2',
    ),
    Vehicle(
      id: 'v4', ownerId: 'demo-uid', plateNumber: 'М234НТ 77',
      brand: 'Mercedes', model: 'Actros', year: 2022, fuelType: 'diesel',
      createdAt: now.subtract(const Duration(days: 90)),
      isActive: false,
    ),
    Vehicle(
      id: 'v5', ownerId: 'demo-uid', plateNumber: 'С567УХ 116',
      brand: 'КАМАЗ', model: '54901', year: 2023, fuelType: 'diesel',
      createdAt: now.subtract(const Duration(days: 30)),
      isActive: false,
    ),
  ];

  static final List<Trip> trips = [
    Trip(
      id: 't1', driverId: 'd1', vehicleId: 'v1', status: TripStatus.completed,
      startTime: now.subtract(const Duration(days: 5)),
      startLatitude: 55.7558, startLongitude: 37.6173,
      endTime: now.subtract(const Duration(days: 4, hours: 20)),
      endLatitude: 55.7961, endLongitude: 49.1064,
      mileage: 820.5, mileageSource: MileageSource.auto,
      routeDescription: 'Москва — Казань', cargoDescription: 'Стройматериалы, 20 т',
      income: 120000, createdAt: now.subtract(const Duration(days: 5)),
    ),
    Trip(
      id: 't2', driverId: 'd2', vehicleId: 'v3', status: TripStatus.completed,
      startTime: now.subtract(const Duration(days: 3)),
      startLatitude: 55.7558, startLongitude: 37.6173,
      endTime: now.subtract(const Duration(days: 2, hours: 22)),
      endLatitude: 59.9343, endLongitude: 30.3351,
      mileage: 715.0, mileageSource: MileageSource.auto,
      routeDescription: 'Москва — Санкт-Петербург', cargoDescription: 'Продукты питания, 18 т',
      income: 95000, createdAt: now.subtract(const Duration(days: 3)),
    ),
    Trip(
      id: 't3', driverId: 'd1', vehicleId: 'v1', status: TripStatus.completed,
      startTime: now.subtract(const Duration(days: 10)),
      startLatitude: 55.7558, startLongitude: 37.6173,
      endTime: now.subtract(const Duration(days: 8)),
      endLatitude: 56.3269, endLongitude: 44.0059,
      mileage: 425.3, mileageSource: MileageSource.manual, manualMileage: 430,
      routeDescription: 'Москва — Нижний Новгород', cargoDescription: 'Бытовая техника, 15 т',
      income: 68000, createdAt: now.subtract(const Duration(days: 10)),
    ),
    Trip(
      id: 't4', driverId: 'd3', vehicleId: 'v4', status: TripStatus.active,
      startTime: now.subtract(const Duration(hours: 3)),
      startLatitude: 59.9343, startLongitude: 30.3351,
      mileage: 0, mileageSource: MileageSource.auto,
      routeDescription: 'Санкт-Петербург — Псков', cargoDescription: 'Оборудование',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
  ];

  static final List<Map<String, dynamic>> drivers = [
    {'uid': 'd1', 'displayName': 'Кузнецов Павел', 'email': 'pavel@numino.ru', 'phone': '+79161234567', 'ownerId': 'demo-uid'},
    {'uid': 'd2', 'displayName': 'Сидоров Андрей', 'email': 'andrey@numino.ru', 'phone': '+79169876543', 'ownerId': 'demo-uid'},
    {'uid': 'd3', 'displayName': 'Фёдоров Илья', 'email': 'ilya@numino.ru', 'phone': '+79165551234', 'ownerId': 'demo-uid'},
  ];

  static final List<Expense> expenses = [
    Expense(id: 'e1', tripId: 't1', driverId: 'd1', amount: 18500, category: ExpenseCategory.fuel, description: 'Заправка на М7', latitude: 55.9, longitude: 40.5, photoTimestamp: now.subtract(const Duration(days: 5)), createdAt: now.subtract(const Duration(days: 5))),
    Expense(id: 'e2', tripId: 't1', driverId: 'd1', amount: 1200, category: ExpenseCategory.parking, description: 'Стоянка в Казани', latitude: 55.79, longitude: 49.10, photoTimestamp: now.subtract(const Duration(days: 4, hours: 21)), createdAt: now.subtract(const Duration(days: 4, hours: 21))),
    Expense(id: 'e3', tripId: 't2', driverId: 'd2', amount: 15200, category: ExpenseCategory.fuel, description: 'Заправка на М11', latitude: 57.9, longitude: 32.0, photoTimestamp: now.subtract(const Duration(days: 3)), createdAt: now.subtract(const Duration(days: 3))),
    Expense(id: 'e4', tripId: 't2', driverId: 'd2', amount: 3500, category: ExpenseCategory.repair, description: 'Замена лампочки', latitude: 59.9, longitude: 30.3, photoTimestamp: now.subtract(const Duration(days: 2, hours: 22)), createdAt: now.subtract(const Duration(days: 2, hours: 22))),
    Expense(id: 'e5', tripId: 't3', driverId: 'd1', amount: 8400, category: ExpenseCategory.fuel, description: 'Заправка', latitude: 56.0, longitude: 40.0, photoTimestamp: now.subtract(const Duration(days: 9)), createdAt: now.subtract(const Duration(days: 9))),
    Expense(id: 'e6', tripId: 't3', driverId: 'd1', amount: 600, category: ExpenseCategory.washing, description: 'Мойка', latitude: 56.3, longitude: 44.0, photoTimestamp: now.subtract(const Duration(days: 8)), createdAt: now.subtract(const Duration(days: 8))),
    Expense(id: 'e7', tripId: 't1', driverId: 'd1', amount: 800, category: ExpenseCategory.toll, description: 'Платный участок М7', latitude: 55.85, longitude: 39.0, photoTimestamp: now.subtract(const Duration(days: 4, hours: 23)), createdAt: now.subtract(const Duration(days: 4, hours: 23))),
  ];

  static final List<SalaryRule> salaryRules = [
    SalaryRule(id: 'sr1', ownerId: 'demo-uid', driverId: 'd1', type: SalaryRuleType.percent, percentValue: 15, isActive: true, createdAt: now.subtract(const Duration(days: 30))),
    SalaryRule(id: 'sr2', ownerId: 'demo-uid', driverId: 'd2', type: SalaryRuleType.fixed, fixedValue: 5000, isActive: true, createdAt: now.subtract(const Duration(days: 20))),
    SalaryRule(id: 'sr3', ownerId: 'demo-uid', driverId: 'd3', type: SalaryRuleType.percent, percentValue: 12, isActive: true, createdAt: now.subtract(const Duration(days: 10))),
  ];

  static final List<SalaryPayment> salaryPayments = [
    SalaryPayment(id: 'sp1', ownerId: 'demo-uid', driverId: 'd1', periodStart: now.subtract(const Duration(days: 30)), periodEnd: now.subtract(const Duration(days: 1)), tripIds: ['t1', 't3'], totalIncome: 188000, calculatedSalary: 28200, ruleType: SalaryRuleType.percent, ruleValue: 15, status: SalaryPaymentStatus.calculated, createdAt: now.subtract(const Duration(days: 1))),
    SalaryPayment(id: 'sp2', ownerId: 'demo-uid', driverId: 'd2', periodStart: now.subtract(const Duration(days: 30)), periodEnd: now.subtract(const Duration(days: 1)), tripIds: ['t2'], totalIncome: 95000, calculatedSalary: 5000, ruleType: SalaryRuleType.fixed, ruleValue: 5000, status: SalaryPaymentStatus.paid, createdAt: now.subtract(const Duration(days: 1)), paidAt: now.subtract(const Duration(hours: 12))),
  ];

  static double get totalIncome => trips.where((t) => t.status == TripStatus.completed).fold(0.0, (s, t) => s + (t.income ?? 0));
  static double get totalMileage => trips.where((t) => t.status == TripStatus.completed).fold(0.0, (s, t) => s + t.mileage);
  static int get activeTripsCount => trips.where((t) => t.status == TripStatus.active).length;
  static int get completedTripsCount => trips.where((t) => t.status == TripStatus.completed).length;
}
