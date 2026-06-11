-- YDB Schema for Numino (CargoProfi)
-- Parity with Firestore collections

CREATE TABLE owners (
    uid Utf8,
    email Utf8,
    password_hash Utf8,
    role Utf8,
    display_name Utf8,
    phone Utf8,
    company_name Utf8,
    driver_ids Json,
    active Bool,
    created_at Timestamp,
    PRIMARY KEY (uid)
);

CREATE TABLE drivers (
    uid Utf8,
    owner_id Utf8,
    email Utf8,
    display_name Utf8,
    phone Utf8,
    role Utf8,
    assigned_vehicle_id Utf8,
    license_number Utf8,
    med_exam_number Utf8,
    med_exam_date Timestamp,
    med_exam_photo_url Utf8,
    created_at Timestamp,
    PRIMARY KEY (uid),
    INDEX owner_idx GLOBAL ON (owner_id)
);

CREATE TABLE vehicles (
    id Utf8,
    owner_id Utf8,
    plate_number Utf8,
    brand Utf8,
    model Utf8,
    year Int32,
    vin Utf8,
    fuel_type Utf8,
    is_active Bool,
    active_driver_id Utf8,
    tech_exam_number Utf8,
    tech_exam_date Timestamp,
    tech_exam_photo_url Utf8,
    created_at Timestamp,
    PRIMARY KEY (id),
    INDEX owner_idx GLOBAL ON (owner_id)
);

CREATE TABLE trips (
    id Utf8,
    driver_id Utf8,
    vehicle_id Utf8,
    status Utf8,
    start_time Timestamp,
    start_latitude Double,
    start_longitude Double,
    track Json,
    end_time Timestamp,
    end_latitude Double,
    end_longitude Double,
    mileage Double,
    mileage_source Utf8,
    manual_mileage Double,
    cargo_description Utf8,
    route_description Utf8,
    income Double,
    waybill_url Utf8,
    waybill_uuid Utf8,
    created_at Timestamp,
    updated_at Timestamp,
    PRIMARY KEY (id),
    INDEX driver_idx GLOBAL ON (driver_id),
    INDEX status_idx GLOBAL ON (status)
);

CREATE TABLE expenses (
    id Utf8,
    trip_id Utf8,
    driver_id Utf8,
    amount Double,
    category Utf8,
    description Utf8,
    receipt_url Utf8,
    latitude Double,
    longitude Double,
    photo_timestamp Timestamp,
    created_at Timestamp,
    PRIMARY KEY (id),
    INDEX trip_idx GLOBAL ON (trip_id),
    INDEX driver_idx GLOBAL ON (driver_id)
);

CREATE TABLE salary_rules (
    id Utf8,
    owner_id Utf8,
    driver_id Utf8,
    type Utf8,
    percent_value Double,
    fixed_value Double,
    is_active Bool,
    created_at Timestamp,
    updated_at Timestamp,
    PRIMARY KEY (id),
    INDEX owner_idx GLOBAL ON (owner_id)
);

CREATE TABLE salary_payments (
    id Utf8,
    owner_id Utf8,
    driver_id Utf8,
    period_start Timestamp,
    period_end Timestamp,
    trip_ids Json,
    total_income Double,
    calculated_salary Double,
    rule_type Utf8,
    rule_value Double,
    status Utf8,
    created_at Timestamp,
    paid_at Timestamp,
    PRIMARY KEY (id),
    INDEX driver_idx GLOBAL ON (driver_id)
);

CREATE TABLE tickets (
    id Utf8,
    name Utf8,
    email Utf8,
    message Utf8,
    status Utf8,
    created_at Timestamp,
    PRIMARY KEY (id)
);

CREATE TABLE admin_logs (
    id Utf8,
    action Utf8,
    detail Utf8,
    admin_uid Utf8,
    created_at Timestamp,
    PRIMARY KEY (id)
);

CREATE TABLE tariffs (
    owner_id Utf8,
    plan Utf8,
    assigned_at Timestamp,
    PRIMARY KEY (owner_id)
);
