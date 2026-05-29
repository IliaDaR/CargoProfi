import * as admin from "firebase-admin";

admin.initializeApp();

export {
  startTrip,
  addTrackPoint,
  addTrackPointsBatch,
  endTrip,
  getMyTrips,
} from "./trips";

export {
  addExpense,
  getTripExpenses,
  getDriverExpensesReport,
} from "./expenses";

export {generateWaybill} from "./pdf";

export {setSalaryRule, getSalaryRule} from "./salaryRules";

export {calculateSalary, getSalaryHistory} from "./salary";
