
// Тип пользователя
enum UserRole { owner, driver }

// Статус рейса
enum TripStatus { active, completed, cancelled }

// Источник данных пробега
enum MileageSource { auto, manual }

// Категория расхода
enum ExpenseCategory {
  fuel,
  parking,
  repair,
  toll,
  washing,
  tires,
  insurance,
  other
}

// Тип правила зарплаты
enum SalaryRuleType { percent, fixed }

// Статус выплаты зарплаты
enum SalaryPaymentStatus { calculated, paid, cancelled }

// ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

ExpenseCategory expenseCategoryFromString(String value) {
  return ExpenseCategory.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ExpenseCategory.other,
  );
}

String expenseCategoryLabel(ExpenseCategory cat) {
  switch (cat) {
    case ExpenseCategory.fuel:
      return 'Топливо';
    case ExpenseCategory.parking:
      return 'Стоянка';
    case ExpenseCategory.repair:
      return 'Ремонт';
    case ExpenseCategory.toll:
      return 'Дорожный сбор';
    case ExpenseCategory.washing:
      return 'Мойка';
    case ExpenseCategory.tires:
      return 'Шины';
    case ExpenseCategory.insurance:
      return 'Страховка';
    case ExpenseCategory.other:
      return 'Прочее';
  }
}

String mileageSourceLabel(MileageSource src) {
  switch (src) {
    case MileageSource.auto:
      return 'Автоматически';
    case MileageSource.manual:
      return 'Вручную';
  }
}

String tripStatusLabel(TripStatus status) {
  switch (status) {
    case TripStatus.active:
      return 'В рейсе';
    case TripStatus.completed:
      return 'Завершён';
    case TripStatus.cancelled:
      return 'Отменён';
  }
}

String salaryRuleTypeLabel(SalaryRuleType type) {
  switch (type) {
    case SalaryRuleType.percent:
      return '% от дохода';
    case SalaryRuleType.fixed:
      return 'Фикс за рейс';
  }
}
