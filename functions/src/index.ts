import * as admin from "firebase-admin";

admin.initializeApp();

export {
  startTrip,
  addTrackPoint,
  addTrackPointsBatch,
  endTrip,
  updateTrip,
  getMyTrips,
} from "./trips";

export {
  addExpense,
  getTripExpenses,
  getDriverExpensesReport,
} from "./expenses";

export {generateWaybill} from "./pdf";
export {signWaybill} from "./goskluch";

export {setSalaryRule, getSalaryRule} from "./salaryRules";

export {calculateSalary, getSalaryHistory} from "./salary";

export {checkWaybill} from "./check";
export {generateInviteCode, validateInviteCode} from "./invites";
export {getOwnerNotifications, markNotificationRead} from "./notifications";
