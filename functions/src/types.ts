import {Timestamp} from "firebase-admin/firestore";

export type UserRole = "owner" | "driver";

export type TripStatus = "active" | "completed" | "cancelled";

export type SalaryRuleType = "percent" | "fixed";

export type MileageSource = "auto" | "manual";

export interface OwnerProfile {
  uid: string;
  role: "owner";
  displayName: string;
  email: string;
  phone?: string;
  companyName?: string;
  driverIds: string[];
  createdAt: Timestamp;
}

export interface DriverProfile {
  uid: string;
  role: "driver";
  displayName: string;
  email: string;
  phone?: string;
  ownerId: string;
  assignedVehicleId?: string;
  licenseNumber?: string;
  createdAt: Timestamp;
}

export interface Vehicle {
  id: string;
  ownerId: string;
  plateNumber: string;
  brand: string;
  model: string;
  year?: number;
  vin?: string;
  registrationNumber?: string;
  fuelType?: string;
  createdAt: Timestamp;
}

export interface GeoPoint {
  latitude: number;
  longitude: number;
  timestamp: Timestamp;
}

export interface Trip {
  id: string;
  driverId: string;
  vehicleId: string;
  status: TripStatus;
  startTime: Timestamp;
  startLocation: {
    latitude: number;
    longitude: number;
  };
  track: GeoPoint[];
  endTime?: Timestamp;
  endLocation?: {
    latitude: number;
    longitude: number;
  };
  mileage: number;
  mileageSource: MileageSource;
  manualMileage?: number;
  cargoDescription?: string;
  routeDescription?: string;
  income?: number;
  waybillUrl?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export type ExpenseCategory =
  | "fuel"
  | "parking"
  | "repair"
  | "toll"
  | "washing"
  | "tires"
  | "insurance"
  | "other";

export interface Expense {
  id: string;
  tripId: string;
  driverId: string;
  amount: number;
  category: ExpenseCategory;
  description?: string;
  receiptUrl?: string;
  location: {
    latitude: number;
    longitude: number;
  };
  photoTimestamp: Timestamp;
  createdAt: Timestamp;
}

export interface SalaryRule {
  id: string;
  ownerId: string;
  driverId: string;
  type: SalaryRuleType;
  percentValue?: number;
  fixedValue?: number;
  isActive: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface SalaryPayment {
  id: string;
  ownerId: string;
  driverId: string;
  periodStart: Timestamp;
  periodEnd: Timestamp;
  tripIds: string[];
  totalIncome: number;
  calculatedSalary: number;
  ruleType: SalaryRuleType;
  ruleValue: number;
  status: "calculated" | "paid" | "cancelled";
  createdAt: Timestamp;
  paidAt?: Timestamp;
}

export interface StartTripInput {
  vehicleId: string;
  latitude: number;
  longitude: number;
  cargoDescription?: string;
  routeDescription?: string;
}

export interface AddTrackPointInput {
  tripId: string;
  latitude: number;
  longitude: number;
}

export interface EndTripInput {
  tripId: string;
  latitude: number;
  longitude: number;
  manualMileage?: number;
  income?: number;
}

export interface AddExpenseInput {
  tripId: string;
  amount: number;
  category: ExpenseCategory;
  description?: string;
  latitude: number;
  longitude: number;
}

export interface SetSalaryRuleInput {
  driverId: string;
  type: SalaryRuleType;
  percentValue?: number;
  fixedValue?: number;
}

export interface CalculateSalaryInput {
  driverId: string;
  periodStart: string;
  periodEnd: string;
}
