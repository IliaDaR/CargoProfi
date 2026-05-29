# Структура базы данных Firestore

## Коллекции

### `owners`
Профили владельцев парка (плательщиков).

```json
{
  "uid": "string (document ID = Firebase Auth UID)",
  "role": "owner",
  "displayName": "Иван Петров",
  "email": "ivan@example.com",
  "phone": "+79001234567",
  "companyName": "ООО Грузовик",
  "driverIds": ["driver_uid_1", "driver_uid_2"],
  "createdAt": "Timestamp"
}
```

### `drivers`
Профили водителей.

```json
{
  "uid": "string (document ID = Firebase Auth UID)",
  "role": "driver",
  "displayName": "Пётр Сидоров",
  "email": "petr@example.com",
  "phone": "+79009876543",
  "ownerId": "owner_uid",
  "assignedVehicleId": "vehicle_id_1",
  "licenseNumber": "77АА 123456",
  "createdAt": "Timestamp"
}
```

### `vehicles`
Транспортные средства парка.

```json
{
  "id": "string (document ID)",
  "ownerId": "owner_uid",
  "plateNumber": "А123ВС 177",
  "brand": "MAN",
  "model": "TGX",
  "year": 2020,
  "vin": "WMA12...",
  "registrationNumber": "77 ТХ 123456",
  "fuelType": "diesel",
  "createdAt": "Timestamp"
}
```

### `trips`
Рейсы. Содержат GPS-трек и данные о пробеге.

```json
{
  "id": "string (document ID)",
  "driverId": "driver_uid",
  "vehicleId": "vehicle_id",
  "status": "active | completed | cancelled",
  "startTime": "Timestamp",
  "startLocation": {
    "latitude": 55.7558,
    "longitude": 37.6173
  },
  "track": [
    {
      "latitude": 55.7558,
      "longitude": 37.6173,
      "timestamp": "Timestamp"
    },
    ...
  ],
  "endTime": "Timestamp",
  "endLocation": {
    "latitude": 55.7558,
    "longitude": 37.6173
  },
  "mileage": 1250.5,
  "mileageSource": "auto | manual",
  "manualMileage": 1200.0,
  "cargoDescription": "Стройматериалы",
  "routeDescription": "Москва – Казань",
  "income": 150000.00,
  "waybillUrl": "https://storage.googleapis.com/.../waybill.pdf",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### `expenses`
Расходы во время рейсов.

```json
{
  "id": "string (document ID)",
  "tripId": "trip_id",
  "driverId": "driver_uid",
  "amount": 3500.00,
  "category": "fuel | parking | repair | toll | washing | tires | insurance | other",
  "description": "Заправка на М4",
  "receiptUrl": "https://storage.googleapis.com/.../receipt.jpg",
  "location": {
    "latitude": 55.1234,
    "longitude": 37.5678
  },
  "photoTimestamp": "Timestamp",
  "createdAt": "Timestamp"
}
```

### `salaryRules`
Правила начисления зарплаты водителям.

```json
{
  "id": "string (document ID)",
  "ownerId": "owner_uid",
  "driverId": "driver_uid",
  "type": "percent | fixed",
  "percentValue": 15,
  "fixedValue": 5000,
  "isActive": true,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### `salaryPayments`
Результаты расчёта зарплаты.

```json
{
  "id": "string (document ID)",
  "ownerId": "owner_uid",
  "driverId": "driver_uid",
  "periodStart": "Timestamp",
  "periodEnd": "Timestamp",
  "tripIds": ["trip_id_1", "trip_id_2"],
  "totalIncome": 250000.00,
  "calculatedSalary": 37500.00,
  "ruleType": "percent",
  "ruleValue": 15,
  "status": "calculated | paid | cancelled",
  "createdAt": "Timestamp",
  "paidAt": "Timestamp"
}
```

## Firebase Storage

```
receipts/{driverId}/{expenseId}.{ext}  — фото чеков (только image/*, до 10 MB)
waybills/{ownerId}/{tripId}.pdf        — сгенерированные PDF путевых листов
```
