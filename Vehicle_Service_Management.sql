/* =====================================================================
   VEHICLE CARE SQL MASTERCLASS 
   VehicleCare Service Centre.
   Build the database, clean the data, answer the manager.(ETL->Extract,Transform,Load)

   PARTS
     0  Setup
     1  DDL: CREATE, ALTER, DROP, constraints, data types (+ data load)
     2  Aggregation & HAVING
     3  Joins: customers & vehicles, bookings, mechanics, self join
     4  Functions: string, date, math
     5  Data cleaning: NULLs, CASE WHEN, duplicates, standardizing
     6  Window functions: ROW_NUMBER, RANK, DENSE_RANK, LAG / LEAD
     7  KPIs: service centre & revenue analysis

   Revenue rule used everywhere:
     booking revenue = labour charges + parts charges after discounts
     only bookings with status 'Completed' count as revenue
   ===================================================================== */


/* =====================================================================
   PART 0 — SETUP
   ===================================================================== */
DROP DATABASE IF EXISTS vehiclecare;
CREATE DATABASE vehiclecare;
USE vehiclecare;


/* =====================================================================
   PART 1 — DDL: CREATE, ALTER, DROP, CONSTRAINTS, DATA TYPES
   ===================================================================== */

-- 1.1 CREATE TABLE with data types + constraints ----------------------
-- Data types: INT, VARCHAR(n), DECIMAL(p,s), DATE, DATETIME, ENUM
-- Constraints: PRIMARY KEY, NOT NULL, UNIQUE, DEFAULT, CHECK, FOREIGN KEY

-- Mechanics (self-reference: supervisor_id -> mechanic_id, used for SELF JOIN)
CREATE TABLE mechanics (
    mechanic_id    INT PRIMARY KEY,
    mechanic_name  VARCHAR(50) NOT NULL,
    specialization VARCHAR(40) NOT NULL,
    supervisor_id  INT NULL,
    hire_date      DATE NOT NULL,
    monthly_salary DECIMAL(10,2) CHECK (monthly_salary > 0),
    CONSTRAINT fk_mechanic_supervisor
        FOREIGN KEY (supervisor_id) REFERENCES mechanics(mechanic_id)
);

-- Customers (membership_type is added later with ALTER)
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(100) UNIQUE,
    phone       VARCHAR(15),
    city        VARCHAR(50),
    signup_date DATE NOT NULL
);

CREATE TABLE vehicles (
    vehicle_id   INT PRIMARY KEY,
    customer_id  INT NOT NULL,
    registration_no VARCHAR(20) NOT NULL UNIQUE,
    brand        VARCHAR(40) NOT NULL,
    model        VARCHAR(50) NOT NULL,
    manufacture_year INT CHECK (manufacture_year BETWEEN 1990 AND 2026),
    fuel_type    ENUM('Petrol','Diesel','Electric','Hybrid','CNG') NOT NULL,
    CONSTRAINT fk_vehicle_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE service_types (
    service_type_id INT PRIMARY KEY,
    service_name    VARCHAR(80) NOT NULL,
    service_category VARCHAR(40) NOT NULL,
    standard_hours DECIMAL(4,1) CHECK (standard_hours > 0)
);

CREATE TABLE parts (
    part_id     INT PRIMARY KEY,
    part_name   VARCHAR(100) NOT NULL,
    category    VARCHAR(50) NOT NULL,
    selling_price DECIMAL(10,2) NOT NULL CHECK (selling_price > 0),
    cost_price    DECIMAL(10,2) NOT NULL CHECK (cost_price >= 0)
);

CREATE TABLE service_bookings (
    booking_id   INT PRIMARY KEY,
    vehicle_id   INT NOT NULL,
    mechanic_id  INT NULL,
    booking_date DATETIME NOT NULL,
    promised_date DATE,
    status ENUM('Completed','In Progress','Cancelled','On Hold') NOT NULL,
    payment_mode VARCHAR(20),
    CONSTRAINT fk_booking_vehicle
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id),
    CONSTRAINT fk_booking_mechanic
        FOREIGN KEY (mechanic_id) REFERENCES mechanics(mechanic_id)
);

SHOW CREATE TABLE service_bookings;

CREATE TABLE service_tasks (
    task_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    service_type_id INT NOT NULL,
    labour_hours DECIMAL(4,1) NOT NULL CHECK (labour_hours > 0),
    labour_charge DECIMAL(10,2) NOT NULL CHECK (labour_charge >= 0),
    discount_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_task_booking
        FOREIGN KEY (booking_id) REFERENCES service_bookings(booking_id),
    CONSTRAINT fk_task_service
        FOREIGN KEY (service_type_id) REFERENCES service_types(service_type_id)
);

CREATE TABLE booking_parts (
    booking_part_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    part_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    discount_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_booking_part_booking
        FOREIGN KEY (booking_id) REFERENCES service_bookings(booking_id),
    CONSTRAINT fk_booking_part_part
        FOREIGN KEY (part_id) REFERENCES parts(part_id)
);

DESCRIBE mechanics;
DESCRIBE customers;
DESCRIBE vehicles;
DESCRIBE service_types;
DESCRIBE parts;
DESCRIBE service_bookings;
DESCRIBE service_tasks;
DESCRIBE booking_parts;

-- 1.2 ALTER TABLE -------------------------------------------------------
-- Business ask: "Management wants to classify customers by membership."
ALTER TABLE customers ADD COLUMN membership_type VARCHAR(20) DEFAULT 'Regular';

-- "Phone numbers may include country code" -> widen the column
ALTER TABLE customers MODIFY COLUMN phone VARCHAR(20);

-- "Discount can never exceed 40%" -> add a named CHECK constraint
ALTER TABLE booking_parts
ADD CONSTRAINT chk_part_discount CHECK (discount_pct BETWEEN 0 AND 40);

-- Rename a column, then rename it back (demo only)
ALTER TABLE parts RENAME COLUMN cost_price TO purchase_price;
DESCRIBE parts;
ALTER TABLE parts RENAME COLUMN purchase_price TO cost_price;

-- See the result
DESCRIBE customers;

-- 1.3 DROP vs TRUNCATE vs DELETE ---------------------------------------
CREATE TABLE temp_service_offer (
    offer_code VARCHAR(15) PRIMARY KEY,
    discount_pct INT
);
INSERT INTO temp_service_offer VALUES
('SUMMER15',15),('FREEWASH',5);
SELECT * FROM temp_service_offer;
DELETE FROM temp_service_offer WHERE offer_code = 'FREEWASH'; -- chosen rows
TRUNCATE TABLE temp_service_offer;                             -- all rows, table remains
DROP TABLE temp_service_offer;                                 -- removes table
DROP TABLE IF EXISTS temp_service_offer;                        -- safe re-run

-- Insert  values to all tables
-- 1.5 LOAD DATA ---------------------------------------------------------
INSERT INTO mechanics VALUES
(1,'Sathish Kumar','Engine',NULL,'2019-04-01',65000),
(2,'Aravind Raj','General Service',1,'2020-06-15',48000),
(3,'Priya Anand','Electrical',2,'2021-03-10',42000),
(4,'Karthik M','Engine',2,'2022-01-20',40000),
(5,'Meena Joseph','Wheel & Brake',2,'2023-07-01',38000),
(6,'Vijay Kumar','Diagnostics',1,'2020-09-01',52000),
(7,'Divya S','Electrical',6,'2022-11-11',39000),
(8,'Rahul Dev','General Service',2,'2024-02-05',36000);

INSERT INTO customers (customer_id,full_name,email,phone,city,signup_date) VALUES
(1,'Ravi Kumar','ravi.kumar@gmail.com','9843012345','Coimbatore','2025-01-15'),
(2,'Lakshmi Narayanan','lakshmi.n@yahoo.com','9876543210','Chennai','2025-01-28'),
(3,'Suresh Babu',NULL,'9123456780','Bengaluru','2025-02-10'),
(4,'Fathima Begum','fathima.b@gmail.com',NULL,'Coimbatore','2025-02-22'),
(5,'Deepak Verma','deepak.v@outlook.com','9988776655','Mumbai','2025-03-05'),
(6,'Kavya Reddy','kavya.r@gmail.com','9001122334','Hyderabad','2025-03-18'),
(7,'Mohammed Irfan','irfan.m@gmail.com','9445566778','Chennai','2025-04-02'),
(8,'Sneha Pillai','sneha.p@gmail.com',NULL,'Kochi','2025-05-12'),
(9,'Arun Prakash','arun.p@gmail.com','9789012345',NULL,'2025-06-01'),
(10,'Nisha Gupta','nisha.g@gmail.com','9812345670','Delhi','2025-07-19'),
(11,'Gopal Krishnan',NULL,'9677889900','Madurai','2025-09-03'),
(12,'Harini Selvam','harini.s@gmail.com','9500011223','Coimbatore','2025-10-25');

INSERT INTO vehicles VALUES
(201,1,'TN38AB1234','Hyundai','i20',2021,'Petrol'),
(202,2,'TN09CD2345','Maruti','Swift',2020,'Petrol'),
(203,3,'KA03EF3456','Honda','City',2019,'Diesel'),
(204,4,'TN38GH4567','Tata','Nexon',2022,'Electric'),
(205,5,'MH12JK5678','Toyota','Innova',2018,'Diesel'),
(206,6,'TS08LM6789','Kia','Seltos',2023,'Petrol'),
(207,7,'TN10NP7890','Mahindra','XUV300',2021,'Diesel'),
(208,8,'KL07QR8901','Renault','Kwid',2020,'Petrol'),
(209,9,'DL04ST9012','Honda','Activa',2022,'Petrol'),
(210,10,'DL05UV0123','Tata','Tiago',2021,'CNG'),
(211,11,'TN58WX1122','Royal Enfield','Classic 350',2019,'Petrol'),
(212,12,'TN38YZ2233','Ather','450X',2024,'Electric');

INSERT INTO service_types VALUES
(401,'Full Service','Maintenance',4.0),
(402,'Engine Repair','Mechanical',6.0),
(403,'Oil Change','Maintenance',1.0),
(404,'Brake Repair','Safety',2.0),
(405,'Battery Check','Electrical',1.0),
(406,'Wheel Alignment','Safety',1.5),
(407,'AC Service','Electrical',2.5),
(408,'General Inspection','Inspection',1.0);

INSERT INTO parts VALUES
(301,'Engine Oil','Fluids',1200,800),
(302,'Oil Filter','Filters',450,250),
(303,'Brake Pad Set','Brakes',2200,1400),
(304,'Air Filter','Filters',650,350),
(305,'Car Battery','Electrical',5500,4200),
(306,'Spark Plug Set','Engine',900,500),
(307,'Coolant','Fluids',700,400),
(308,'Wiper Blade','Accessories',550,300),
(309,'Headlight Bulb','Electrical',800,450),
(310,'Tyre','Wheels',4200,3200); -- never used

INSERT INTO service_bookings VALUES
(2001,201,3,'2025-01-20 10:15:00','2025-01-21','Completed','UPI'),
(2002,202,4,'2025-02-02 14:30:00','2025-02-04','Completed','Card'),
(2003,201,3,'2025-02-14 19:45:00','2025-02-16','Completed','UPI'),
(2004,203,5,'2025-02-25 11:00:00','2025-02-27','Cancelled','Cash'),
(2005,204,3,'2025-03-03 09:20:00','2025-03-04','Completed','UPI'),
(2006,205,4,'2025-03-21 16:10:00','2025-03-24','Completed','Card'),
(2007,202,4,'2025-04-05 12:00:00','2025-04-07','On Hold','Card'),
(2008,206,8,'2025-04-18 18:30:00','2025-04-20','Completed','UPI'),
(2009,201,3,'2025-05-02 20:05:00','2025-05-04','Completed','UPI'),
(2010,207,5,'2025-05-15 13:40:00','2025-05-16','Completed','Cash'),
(2011,203,5,'2025-06-07 10:25:00','2025-06-09','Completed','UPI'),
(2012,208,8,'2025-06-20 15:15:00','2025-06-22','Completed','Card'),
(2013,205,4,'2025-07-04 11:50:00','2025-07-06','Completed','Card'),
(2014,209,NULL,'2025-07-22 17:35:00','2025-07-23','Completed','UPI'),
(2015,201,3,'2025-08-08 09:05:00','2025-08-10','Completed','Card'),
(2016,206,8,'2025-08-30 19:20:00','2025-09-01','Cancelled','UPI'),
(2017,202,4,'2025-09-12 14:00:00','2025-09-14','Completed','UPI'),
(2018,207,5,'2025-09-28 16:45:00','2025-09-30','Completed','Card'),
(2019,204,3,'2025-10-10 10:10:00','2025-10-12','Completed','UPI'),
(2020,212,8,'2025-10-28 18:00:00','2025-10-29','Completed','UPI'),
(2021,205,4,'2025-11-11 11:11:00','2025-11-13','Completed','Card'),
(2022,201,3,'2025-11-25 20:30:00','2025-11-27','Completed','UPI'),
(2023,208,8,'2025-12-05 13:15:00','2025-12-07','Completed','Cash'),
(2024,212,8,'2025-12-18 15:50:00','2025-12-20','In Progress','UPI'),
(2025,203,5,'2025-12-28 12:20:00','2025-12-30','In Progress','Card');

INSERT INTO service_tasks (booking_id,service_type_id,labour_hours,labour_charge,discount_pct) VALUES
(2001,401,4,2500,0),(2001,403,1,500,0),
(2002,402,5,4500,10),
(2003,401,4,2500,5),(2003,405,1,600,0),
(2004,404,2,1200,0),
(2005,407,2.5,1800,0),(2005,405,1,600,0),
(2006,402,6,5000,10),
(2007,403,1,500,0),
(2008,401,4,2500,0),(2008,406,1.5,900,0),
(2009,404,2,1200,5),
(2010,403,1,500,0),(2010,408,1,400,0),
(2011,402,6,5000,0),
(2012,407,2.5,1800,10),
(2013,402,5,4500,0),(2013,403,1,500,0),
(2014,405,1,600,0),
(2015,401,4,2500,15),(2015,404,2,1200,15),
(2016,402,6,5000,0),
(2017,407,2.5,1800,0),(2017,408,1,400,0),
(2018,406,1.5,900,0),
(2019,402,5,4500,5),(2019,405,1,600,5),
(2020,401,4,2500,0),
(2021,402,6,5000,10),
(2022,402,5,4500,0),(2022,407,2.5,1800,0),
(2023,403,1,500,0),(2023,408,1,400,0),
(2024,401,4,2500,5),
(2025,404,2,1200,0);

INSERT INTO booking_parts (booking_id,part_id,quantity,unit_price,discount_pct) VALUES
(2001,301,2,1200,0),(2001,302,1,450,0),
(2002,306,4,900,10),
(2003,305,1,5500,5),(2003,309,1,800,0),
(2004,303,1,2200,0),
(2005,307,2,700,0),(2005,308,2,550,0),
(2006,303,1,2200,10),
(2007,301,1,1200,0),
(2008,302,1,450,0),(2008,304,1,650,0),
(2009,303,2,2200,5),
(2010,302,2,450,0),(2010,307,1,700,0),
(2011,305,1,5500,0),
(2012,308,2,550,10),
(2013,306,4,900,0),(2013,301,1,1200,0),
(2014,309,1,800,0),
(2015,305,1,5500,15),(2015,303,1,2200,15),
(2016,304,1,650,0),
(2017,308,1,550,0),(2017,302,1,450,0),
(2018,310,2,4200,0),
(2019,306,4,900,5),(2019,307,1,700,5),
(2020,305,1,5500,0),
(2021,303,2,2200,10),
(2022,306,4,900,0),(2022,309,1,800,0),
(2023,302,2,450,0),(2023,307,1,700,0),
(2024,305,1,5500,5),
(2025,301,2,1200,0);

-- Raw customer export for the cleaning module (deliberately messy, NO constraints)
CREATE TABLE customers_raw (
    raw_id INT,
    cust_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(30),
    city VARCHAR(50),
    signup_date VARCHAR(20),
    gender VARCHAR(10)
);

INSERT INTO customers_raw VALUES
(1,'  ravi kumar ','RAVI.KUMAR@GMAIL.COM ','+91 98430-12345','coimbatore','15/01/2025','M'),
(2,'Lakshmi Narayanan','lakshmi.n@yahoo.com','9876543210',' CHENNAI','2025-01-28','f'),
(3,'RAVI KUMAR','ravi.kumar@gmail.com','98430 12345','Coimbatore ','2025-01-15','Male'),
(4,'suresh babu',NULL,'(912) 345-6780','Bengaluru','10-02-2025',NULL),
(5,'Fathima  Begum','fathima.b@gmail.com','','coimbatore','2025/02/22','F'),
(6,'Deepak Verma','deepak.v@outlook.com','+91-9988776655','MUMBAI','05/03/2025','male'),
(7,'deepak verma','DEEPAK.V@OUTLOOK.COM','9988776655','Mumbai','2025-03-05','M'),
(8,'Kavya Reddy','  kavya.r@gmail.com','9001122334','hyderabad',NULL,'Female');

-- Quick check: row counts
SELECT 'mechanics' AS tbl,COUNT(*) AS row_count FROM mechanics
UNION ALL SELECT 'customers',COUNT(*) FROM customers
UNION ALL SELECT 'vehicles',COUNT(*) FROM vehicles
UNION ALL SELECT 'service_bookings',COUNT(*) FROM service_bookings
UNION ALL SELECT 'service_tasks',COUNT(*) FROM service_tasks
UNION ALL SELECT 'booking_parts',COUNT(*) FROM booking_parts
UNION ALL SELECT 'customers_raw',COUNT(*) FROM customers_raw;


/* =====================================================================
   PART 2 — AGGREGATION & HAVING
   WHERE filters ROWS before grouping; HAVING filters GROUPS after.
   ===================================================================== */

-- 2.1 Bookings by status
SELECT status,COUNT(*) AS booking_count
FROM service_bookings
GROUP BY status
ORDER BY booking_count DESC;

-- 2.2 Customers with MORE THAN 2 service bookings (HAVING on COUNT)
SELECT v.customer_id,COUNT(*) AS booking_count
FROM vehicles v
JOIN service_bookings b ON b.vehicle_id=v.vehicle_id
GROUP BY v.customer_id
HAVING COUNT(*)>2
ORDER BY booking_count DESC;

-- 2.3 WHERE + HAVING together:
-- "Among completed bookings, which service categories earned more than Rs 5,000?"
SELECT st.service_category,
       SUM(t.labour_charge*(1-t.discount_pct/100)) AS labour_revenue
FROM service_tasks t
JOIN service_types st ON st.service_type_id=t.service_type_id
JOIN service_bookings b ON b.booking_id=t.booking_id
WHERE b.status='Completed'
GROUP BY st.service_category
HAVING labour_revenue>5000
ORDER BY labour_revenue DESC;

-- 2.4 Payment modes used more than 5 times
SELECT payment_mode,COUNT(*) AS times_used
FROM service_bookings
GROUP BY payment_mode
HAVING COUNT(*)>5;


/* =====================================================================
   PART 3 — JOINS
   ===================================================================== */

-- 3.1 INNER JOIN — show every booking with vehicle and customer details
SELECT b.booking_id,b.booking_date,c.full_name,v.registration_no,
       v.brand,v.model,b.status
FROM service_bookings b
INNER JOIN vehicles v ON v.vehicle_id=b.vehicle_id
INNER JOIN customers c ON c.customer_id=v.customer_id
ORDER BY b.booking_date;

-- 3.2 LEFT JOIN — every vehicle, with booking count (0 if none)
SELECT v.vehicle_id,v.registration_no,v.brand,v.model,
       COUNT(b.booking_id) AS booking_count
FROM vehicles v
LEFT JOIN service_bookings b ON b.vehicle_id=v.vehicle_id
GROUP BY v.vehicle_id,v.registration_no,v.brand,v.model
ORDER BY booking_count DESC;

-- 3.3 FINDING UNMATCHED DATA ------------------------------------------
-- (a) Customers who registered but NEVER booked a service
SELECT c.customer_id,c.full_name,c.signup_date
FROM customers c
LEFT JOIN vehicles v ON v.customer_id=c.customer_id
LEFT JOIN service_bookings b ON b.vehicle_id=v.vehicle_id
WHERE b.booking_id IS NULL;

-- (b) Parts never used in a service (NOT EXISTS)
SELECT p.part_id,p.part_name
FROM parts p
WHERE NOT EXISTS (
    SELECT 1 FROM booking_parts bp WHERE bp.part_id=p.part_id
);

-- (c) Bookings with no mechanic assigned
SELECT b.booking_id,b.vehicle_id
FROM service_bookings b
LEFT JOIN mechanics m ON m.mechanic_id=b.mechanic_id
WHERE m.mechanic_id IS NULL;

-- (d) FULL OUTER JOIN does not exist in MySQL -> LEFT JOIN UNION RIGHT JOIN
--     Mechanics with no bookings AND bookings with no mechanic
SELECT m.mechanic_name,b.booking_id
FROM mechanics m LEFT JOIN service_bookings b ON b.mechanic_id=m.mechanic_id
WHERE b.booking_id IS NULL
UNION
SELECT m.mechanic_name,b.booking_id
FROM mechanics m RIGHT JOIN service_bookings b ON b.mechanic_id=m.mechanic_id
WHERE m.mechanic_id IS NULL;

-- 3.4 MULTI-TABLE JOIN (6 tables) — full service booking detail report
SELECT b.booking_id,DATE(b.booking_date) AS booking_day,
       c.full_name AS customer,v.registration_no,v.brand,v.model,
       st.service_name,t.labour_hours,t.labour_charge,t.discount_pct,
       ROUND(t.labour_charge*(1-t.discount_pct/100),2) AS net_labour_charge,
       COALESCE(m.mechanic_name,'Not Assigned') AS mechanic
FROM service_bookings b
JOIN vehicles v ON v.vehicle_id=b.vehicle_id
JOIN customers c ON c.customer_id=v.customer_id
JOIN service_tasks t ON t.booking_id=b.booking_id
JOIN service_types st ON st.service_type_id=t.service_type_id
LEFT JOIN mechanics m ON m.mechanic_id=b.mechanic_id
ORDER BY b.booking_id;

-- 3.5 SELF JOIN — mechanic and their supervisor
SELECT m.mechanic_name AS mechanic,m.specialization,
       s.mechanic_name AS supervisor
FROM mechanics m
LEFT JOIN mechanics s ON s.mechanic_id=m.supervisor_id
ORDER BY supervisor,mechanic;

-- 3.6 SELF JOIN — mechanics earning more than their supervisor?
SELECT m.mechanic_name,m.monthly_salary,
       s.mechanic_name AS supervisor,s.monthly_salary AS supervisor_salary
FROM mechanics m
JOIN mechanics s ON s.mechanic_id=m.supervisor_id
WHERE m.monthly_salary>s.monthly_salary;

-- 3.7 SELF JOIN — pairs of customers from the same city
SELECT a.city,a.full_name AS customer_1,b.full_name AS customer_2
FROM customers a
JOIN customers b
  ON a.city=b.city
 AND a.customer_id<b.customer_id
ORDER BY a.city;


/* =====================================================================
   PART 4 — FUNCTIONS: STRING, DATE, MATH
   ===================================================================== */

-- 4.1 STRING functions
SELECT full_name,
       UPPER(full_name) AS upper_name,
       LOWER(full_name) AS lower_name,
       LENGTH(full_name) AS name_length,
       SUBSTRING_INDEX(full_name,' ',1) AS first_name,
       SUBSTRING_INDEX(email,'@',-1) AS email_domain,
       CONCAT(LEFT(phone,2),'******',RIGHT(phone,2)) AS masked_phone
FROM customers;

-- TRIM in action: invisible spaces break matching
SELECT cust_name,LENGTH(cust_name) AS raw_len,
       LENGTH(TRIM(cust_name)) AS trimmed_len,
       CONCAT('[',TRIM(cust_name),']') AS shown
FROM customers_raw;

-- Most popular email domains
SELECT SUBSTRING_INDEX(email,'@',-1) AS domain,
       COUNT(*) AS customers
FROM customers
WHERE email IS NOT NULL
GROUP BY domain
ORDER BY customers DESC;

-- 4.2 DATE functions
SELECT NOW() AS right_now,CURDATE() AS today;

SELECT booking_id,booking_date,
       DATE_FORMAT(booking_date,'%d-%b-%Y') AS booking_day,
       DATE_FORMAT(booking_date,'%Y-%m') AS year_month_key,
       DATE_FORMAT(booking_date,'%h:%i %p') AS booking_time,
       YEAR(booking_date) AS yr,
       MONTHNAME(booking_date) AS month_name,
       QUARTER(booking_date) AS qtr,
       DAYNAME(booking_date) AS weekday,
       DATE_ADD(booking_date,INTERVAL 2 DAY) AS estimated_completion,
       DATEDIFF(CURDATE(),booking_date) AS days_ago
FROM service_bookings
LIMIT 10;

-- Bookings by weekday (when do customers visit?)
SELECT DAYNAME(booking_date) AS weekday,COUNT(*) AS bookings
FROM service_bookings
GROUP BY DAYNAME(booking_date),DAYOFWEEK(booking_date)
ORDER BY DAYOFWEEK(booking_date);

-- Days from customer signup to first service booking
SELECT c.full_name,c.signup_date,
       MIN(DATE(b.booking_date)) AS first_booking,
       DATEDIFF(MIN(b.booking_date),c.signup_date) AS days_to_first_booking
FROM customers c
JOIN vehicles v ON v.customer_id=c.customer_id
JOIN service_bookings b ON b.vehicle_id=v.vehicle_id
GROUP BY c.customer_id,c.full_name,c.signup_date;

-- Mechanic tenure in years
SELECT mechanic_name,hire_date,
       TIMESTAMPDIFF(YEAR,hire_date,CURDATE()) AS years_of_service
FROM mechanics;

-- 4.3 MATH functions
SELECT part_name,selling_price,cost_price,
       selling_price-cost_price AS profit_per_part,
       ROUND((selling_price-cost_price)/selling_price*100,1) AS margin_pct,
       ROUND(selling_price*1.18,2) AS price_with_18pct_gst,
       CEIL(selling_price/1000)*1000 AS rounded_up_to_1000,
       FLOOR(selling_price/3) AS three_part_payment_floor,
       TRUNCATE(selling_price/7,1) AS truncate_demo
FROM parts;

SELECT ABS(-250) AS abs_val,
       MOD(17,5) AS remainder,
       POWER(2,10) AS power_val,
       SQRT(144) AS sqrt_val;

-- Even / odd booking IDs with MOD (example: divide bookings into groups)
SELECT booking_id,
       IF(MOD(booking_id,2)=0,'Group A','Group B') AS service_group
FROM service_bookings
LIMIT 6;


/* =====================================================================
   PART 5 — DATA CLEANING
   ===================================================================== */

-- 5.1 HANDLING NULLs ---------------------------------------------------
DESCRIBE customers_raw;
-- NULL is unknown: = NULL never works, use IS NULL
-- Which customers have not provided their email address?
SELECT customer_id,full_name
FROM customers
WHERE email IS NULL;

-- COALESCE returns the first non-NULL value
SELECT * FROM customers;
SELECT customer_id,full_name,
       COALESCE(email,'not provided') AS email,
       COALESCE(phone,'not provided') AS phone,
       COALESCE(city,'Unknown') AS city,
       COALESCE(email,phone,'no contact') AS best_contact
FROM customers;

-- NULLs and aggregates: COUNT(*) counts rows, COUNT(col) skips NULLs
SELECT COUNT(*) AS all_customers,
       COUNT(email) AS with_email,
       COUNT(phone) AS with_phone
FROM customers;

-- NULLIF prevents divide-by-zero
SELECT 100/NULLIF(0,0) AS safe_division;

-- 5.2 CASE WHEN --------------------------------------------------------
-- Booking value buckets
SELECT b.booking_id,
       COALESCE(SUM(t.labour_charge*(1-t.discount_pct/100)),0)
       +COALESCE(SUM(DISTINCT bp.unit_price),0) AS approximate_booking_value,
       CASE
         WHEN COALESCE(SUM(t.labour_charge),0)>=5000 THEN 'High'
         WHEN COALESCE(SUM(t.labour_charge),0)>=2000 THEN 'Medium'
         ELSE 'Low'
       END AS booking_bucket
FROM service_bookings b
LEFT JOIN service_tasks t ON t.booking_id=b.booking_id
LEFT JOIN booking_parts bp ON bp.booking_id=b.booking_id
GROUP BY b.booking_id;

-- Conditional aggregation: pivot booking status counts into columns
SELECT QUARTER(booking_date) AS qtr,
       COUNT(*) AS total_bookings,
       SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS completed,
       SUM(CASE WHEN status='In Progress' THEN 1 ELSE 0 END) AS in_progress,
       SUM(CASE WHEN status='Cancelled' THEN 1 ELSE 0 END) AS cancelled,
       SUM(CASE WHEN status='On Hold' THEN 1 ELSE 0 END) AS on_hold
FROM service_bookings
GROUP BY QUARTER(booking_date)
ORDER BY qtr;

-- 5.3 FINDING & REMOVING DUPLICATES -----------------------------------
-- (a) DISTINCT: unique values only
SELECT DISTINCT city FROM customers;

-- (b) Find duplicate customers in raw export (after normalising email)
SELECT LOWER(TRIM(email)) AS clean_email,COUNT(*) AS copies
FROM customers_raw
WHERE email IS NOT NULL
GROUP BY clean_email
HAVING COUNT(*)>1;

-- (c) ROW_NUMBER to flag duplicates (keep row 1, earliest raw_id)
SELECT raw_id,cust_name,email,
       ROW_NUMBER() OVER (
           PARTITION BY LOWER(TRIM(email))
           ORDER BY raw_id
       ) AS rn
FROM customers_raw
WHERE email IS NOT NULL;

-- 5.4 STANDARDIZING FORMATS + DEDUPE -> build a clean table -----------
DROP TABLE IF EXISTS customers_clean;

CREATE TABLE customers_clean AS
WITH step1 AS (
    SELECT raw_id,
           REGEXP_REPLACE(TRIM(cust_name),' +',' ') AS name_1space,
           NULLIF(LOWER(TRIM(email)),'') AS email_clean,
           NULLIF(RIGHT(REGEXP_REPLACE(phone,'[^0-9]',''),10),'') AS phone_clean,
           CONCAT(UPPER(LEFT(TRIM(city),1)),
                  LOWER(SUBSTRING(TRIM(city),2))) AS city_clean,
           CASE
             WHEN signup_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
               THEN STR_TO_DATE(signup_date,'%Y-%m-%d')
             WHEN signup_date REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
               THEN STR_TO_DATE(signup_date,'%Y/%m/%d')
             WHEN signup_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
               THEN STR_TO_DATE(signup_date,'%d/%m/%Y')
             WHEN signup_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
               THEN STR_TO_DATE(signup_date,'%d-%m-%Y')
           END AS signup_date_clean,
           CASE UPPER(LEFT(TRIM(gender),1))
             WHEN 'M' THEN 'Male'
             WHEN 'F' THEN 'Female'
             ELSE 'Unknown'
           END AS gender_clean
    FROM customers_raw
),
step2 AS (
    SELECT *,
           CONCAT(
             UPPER(LEFT(SUBSTRING_INDEX(name_1space,' ',1),1)),
             LOWER(SUBSTRING(SUBSTRING_INDEX(name_1space,' ',1),2)),
             ' ',
             UPPER(LEFT(SUBSTRING_INDEX(name_1space,' ',-1),1)),
             LOWER(SUBSTRING(SUBSTRING_INDEX(name_1space,' ',-1),2))
           ) AS full_name,
           ROW_NUMBER() OVER (
             PARTITION BY COALESCE(email_clean,phone_clean)
             ORDER BY raw_id
           ) AS rn
    FROM step1
)
SELECT raw_id,full_name,email_clean AS email,phone_clean AS phone,
       city_clean AS city,signup_date_clean AS signup_date,
       gender_clean AS gender
FROM step2
WHERE rn=1;

-- Before vs after
SELECT * FROM customers_raw ORDER BY raw_id;
SELECT * FROM customers_clean ORDER BY raw_id;


/* =====================================================================
   PART 6 — WINDOW FUNCTIONS
   Aggregate WITHOUT collapsing rows:
   func() OVER (PARTITION BY .. ORDER BY ..)
   ===================================================================== */

CREATE DATABASE IF NOT EXISTS vehiclecare_window_lab;
USE vehiclecare_window_lab;

-- Recreate sample table (safe to run again)
DROP TABLE IF EXISTS mechanic_jobs;

CREATE TABLE mechanic_jobs (
    job_id INT PRIMARY KEY,
    mechanic VARCHAR(30) NOT NULL,
    specialization VARCHAR(30) NOT NULL,
    job_date DATE NOT NULL,
    job_amount DECIMAL(10,2) NOT NULL
);

-- Insert sample data
INSERT INTO mechanic_jobs (job_id,mechanic,specialization,job_date,job_amount) VALUES
(1,'Arun','Engine','2026-01-05',5000),
(2,'Bala','Engine','2026-01-08',4000),
(3,'Charan','Engine','2026-01-12',4000),
(4,'Arun','Engine','2026-02-05',6000),
(5,'Bala','Engine','2026-02-09',3000),
(6,'Charan','Engine','2026-02-15',4500),
(7,'David','Electrical','2026-01-10',2500),
(8,'David','Electrical','2026-02-11',3500),
(9,'Esha','Electrical','2026-01-14',3500),
(10,'Esha','Electrical','2026-02-18',4500);

-- View sample data
SELECT * FROM mechanic_jobs ORDER BY job_date,job_id;

-- A. ROW_NUMBER()
-- Gives each row a unique sequential number.
-- Tie-breaker job_id makes the order deterministic.
SELECT mechanic,specialization,job_amount,
       ROW_NUMBER() OVER (ORDER BY job_amount DESC,job_id) AS row_num
FROM mechanic_jobs;

-- B. RANK()
-- Equal values receive same rank; following ranks are skipped.
SELECT mechanic,job_amount,
       RANK() OVER (ORDER BY job_amount DESC) AS job_rank
FROM mechanic_jobs;

-- C. DENSE_RANK()
-- Equal values receive same rank; no rank numbers are skipped.
SELECT mechanic,job_amount,
       DENSE_RANK() OVER (ORDER BY job_amount DESC) AS dense_job_rank
FROM mechanic_jobs;

-- D. PARTITION BY
-- Starts ranking again within each specialization.
SELECT mechanic,specialization,job_amount,
       RANK() OVER (
           PARTITION BY specialization
           ORDER BY job_amount DESC
       ) AS specialization_rank
FROM mechanic_jobs;

-- E. LAG()
-- Gets the previous job amount for each mechanic, ordered by date.
SELECT mechanic,job_date,job_amount,
       LAG(job_amount) OVER (
           PARTITION BY mechanic
           ORDER BY job_date,job_id
       ) AS previous_job_amount
FROM mechanic_jobs;

-- F. LEAD()
-- Gets the next existing job amount for each mechanic; it does not forecast.
SELECT mechanic,job_date,job_amount,
       LEAD(job_amount) OVER (
           PARTITION BY mechanic
           ORDER BY job_date,job_id
       ) AS next_job_amount
FROM mechanic_jobs;

-- G. TOP 2 JOB RECORDS FOR EACH SPECIALIZATION
-- ROW_NUMBER ensures no more than two rows per specialization.
WITH ranked_jobs AS (
    SELECT job_id,mechanic,specialization,job_amount,
           ROW_NUMBER() OVER (
               PARTITION BY specialization
               ORDER BY job_amount DESC,job_id
           ) AS rn
    FROM mechanic_jobs
)
SELECT job_id,mechanic,specialization,job_amount,rn
FROM ranked_jobs
WHERE rn<=2
ORDER BY specialization,rn;

-- H. TOP 2 DISTINCT JOB AMOUNT LEVELS IN EACH SPECIALIZATION
-- DENSE_RANK keeps ties and returns the top two distinct values.
WITH ranked_jobs AS (
    SELECT job_id,mechanic,specialization,job_amount,
           DENSE_RANK() OVER (
               PARTITION BY specialization
               ORDER BY job_amount DESC
           ) AS job_level
    FROM mechanic_jobs
)
SELECT job_id,mechanic,specialization,job_amount,job_level
FROM ranked_jobs
WHERE job_level<=2
ORDER BY specialization,job_level,mechanic;

-- I. MONTHLY SERVICE REVENUE TREND USING LAG()
WITH monthly_jobs AS (
    SELECT DATE_FORMAT(job_date,'%Y-%m') AS service_month,
           SUM(job_amount) AS total_revenue
    FROM mechanic_jobs
    GROUP BY DATE_FORMAT(job_date,'%Y-%m')
),
monthly_comparison AS (
    SELECT service_month,total_revenue,
           LAG(total_revenue) OVER (ORDER BY service_month) AS previous_month_revenue
    FROM monthly_jobs
)
SELECT service_month,total_revenue,previous_month_revenue,
       total_revenue-previous_month_revenue AS revenue_difference
FROM monthly_comparison
ORDER BY service_month;

-- J. MONTH-OVER-MONTH PERCENTAGE CHANGE
WITH monthly_jobs AS (
    SELECT DATE_FORMAT(job_date,'%Y-%m') AS service_month,
           SUM(job_amount) AS total_revenue
    FROM mechanic_jobs
    GROUP BY DATE_FORMAT(job_date,'%Y-%m')
),
monthly_comparison AS (
    SELECT service_month,total_revenue,
           LAG(total_revenue) OVER (ORDER BY service_month) AS previous_month_revenue
    FROM monthly_jobs
)
SELECT service_month,total_revenue,previous_month_revenue,
       ROUND(
         (total_revenue-previous_month_revenue)
         /NULLIF(previous_month_revenue,0)*100,2
       ) AS growth_percentage
FROM monthly_comparison
ORDER BY service_month;

-- K. RUNNING TOTAL (additional useful window function example)
SELECT job_date,job_id,mechanic,job_amount,
       SUM(job_amount) OVER (
           ORDER BY job_date,job_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total
FROM mechanic_jobs;


/* =====================================================================
   PART 7 — KPI CREATION: SERVICE CENTRE & REVENUE ANALYSIS
   Fixed reference date '2025-12-31' keeps results reproducible.
   In production replace it with CURDATE().
   ===================================================================== */

USE vehiclecare;

-- Create one row per booking with labour revenue + parts revenue and cost.
DROP VIEW IF EXISTS v_booking_revenue;
CREATE VIEW v_booking_revenue AS
SELECT b.booking_id,b.vehicle_id,b.mechanic_id,b.booking_date,b.status,
       b.payment_mode,
       COALESCE(t.labour_revenue,0)+COALESCE(p.parts_revenue,0) AS revenue,
       COALESCE(p.parts_cost,0) AS parts_cost
FROM service_bookings b
LEFT JOIN (
    SELECT booking_id,
           SUM(labour_charge*(1-discount_pct/100)) AS labour_revenue
    FROM service_tasks
    GROUP BY booking_id
) t ON t.booking_id=b.booking_id
LEFT JOIN (
    SELECT bp.booking_id,
           SUM(bp.quantity*bp.unit_price*(1-bp.discount_pct/100)) AS parts_revenue,
           SUM(bp.quantity*pt.cost_price) AS parts_cost
    FROM booking_parts bp
    JOIN parts pt ON pt.part_id=bp.part_id
    GROUP BY bp.booking_id
) p ON p.booking_id=b.booking_id;

-- 7.1 Executive KPI dashboard (one row)
SELECT COUNT(*) AS total_bookings,
       SUM(status='Completed') AS completed_bookings,
       ROUND(SUM(CASE WHEN status='Completed' THEN revenue END),2) AS total_revenue,
       ROUND(AVG(CASE WHEN status='Completed' THEN revenue END),2) AS avg_booking_value,
       COUNT(DISTINCT CASE WHEN status='Completed' THEN vehicle_id END) AS serviced_vehicles,
       ROUND(SUM(status='Cancelled')/COUNT(*)*100,1) AS cancel_rate_pct,
       ROUND(SUM(status='On Hold')/COUNT(*)*100,1) AS on_hold_rate_pct,
       ROUND(
         (SUM(CASE WHEN status='Completed' THEN revenue END)
          -SUM(CASE WHEN status='Completed' THEN parts_cost END))
         /NULLIF(SUM(CASE WHEN status='Completed' THEN revenue END),0)*100,1
       ) AS gross_margin_pct
FROM v_booking_revenue;

-- 7.2 Revenue by service category with % share of total
SELECT st.service_category,
       ROUND(SUM(t.labour_charge*(1-t.discount_pct/100)),2) AS revenue,
       ROUND(
         SUM(t.labour_charge*(1-t.discount_pct/100))*100
         /SUM(SUM(t.labour_charge*(1-t.discount_pct/100))) OVER (),1
       ) AS pct_share
FROM service_tasks t
JOIN service_types st ON st.service_type_id=t.service_type_id
JOIN service_bookings b ON b.booking_id=t.booking_id
WHERE b.status='Completed'
GROUP BY st.service_category
ORDER BY revenue DESC;

-- 7.3 Quarterly service revenue
SELECT YEAR(booking_date) AS yr,QUARTER(booking_date) AS qtr,
       COUNT(*) AS bookings,ROUND(SUM(revenue),2) AS revenue
FROM v_booking_revenue
WHERE status='Completed'
GROUP BY YEAR(booking_date),QUARTER(booking_date)
ORDER BY yr,qtr;

-- 7.4 Customer lifetime value (CLV) + top 5 customers
SELECT c.customer_id,c.full_name,c.city,
       COUNT(v.booking_id) AS completed_bookings,
       ROUND(SUM(v.revenue),2) AS lifetime_value,
       ROUND(AVG(v.revenue),2) AS avg_booking_value,
       DENSE_RANK() OVER (ORDER BY SUM(v.revenue) DESC) AS clv_rank
FROM customers c
JOIN vehicles vh ON vh.customer_id=c.customer_id
JOIN v_booking_revenue v ON v.vehicle_id=vh.vehicle_id
WHERE v.status='Completed'
GROUP BY c.customer_id,c.full_name,c.city
ORDER BY lifetime_value DESC
LIMIT 5;

-- 7.5 Repeat-customer rate
WITH per_customer AS (
    SELECT vh.customer_id,COUNT(*) AS bookings
    FROM vehicles vh
    JOIN service_bookings b ON b.vehicle_id=vh.vehicle_id
    WHERE b.status='Completed'
    GROUP BY vh.customer_id
)
SELECT COUNT(*) AS serviced_customers,
       SUM(bookings>1) AS repeat_customers,
       ROUND(SUM(bookings>1)/COUNT(*)*100,1) AS repeat_rate_pct
FROM per_customer;

-- 7.6 RFM-style customer segmentation (Recency, Frequency, Monetary)
WITH rfm AS (
    SELECT c.customer_id,c.full_name,
           DATEDIFF('2025-12-31',MAX(v.booking_date)) AS recency_days,
           COUNT(v.booking_id) AS frequency,
           COALESCE(SUM(v.revenue),0) AS monetary
    FROM customers c
    LEFT JOIN vehicles vh ON vh.customer_id=c.customer_id
    LEFT JOIN v_booking_revenue v
      ON v.vehicle_id=vh.vehicle_id AND v.status='Completed'
    GROUP BY c.customer_id,c.full_name
)
SELECT customer_id,full_name,recency_days,frequency,ROUND(monetary,2) AS monetary,
       CASE
         WHEN frequency=0 THEN 'No Service Yet'
         WHEN frequency>=4 AND monetary>=15000 THEN 'VIP Customer'
         WHEN frequency>=2 AND recency_days<=90 THEN 'Loyal Customer'
         WHEN recency_days>150 THEN 'At Risk'
         ELSE 'Potential'
       END AS customer_segment
FROM rfm
ORDER BY monetary DESC;

-- 7.7 Write the segment back to customers table (UPDATE with JOIN)
UPDATE customers c
JOIN (
    SELECT vh.customer_id,SUM(v.revenue) AS monetary,COUNT(*) AS frequency
    FROM vehicles vh
    JOIN v_booking_revenue v ON v.vehicle_id=vh.vehicle_id
    WHERE v.status='Completed'
    GROUP BY vh.customer_id
) s ON s.customer_id=c.customer_id
SET c.membership_type=CASE
    WHEN s.frequency>=4 AND s.monetary>=15000 THEN 'VIP'
    WHEN s.monetary>=7000 THEN 'Premium'
    ELSE 'Regular'
END;

SELECT membership_type,COUNT(*) AS customers
FROM customers
GROUP BY membership_type;

-- 7.8 Mechanic performance + share of service centre revenue
SELECT COALESCE(m.mechanic_name,'Unassigned') AS mechanic,
       COUNT(v.booking_id) AS completed_bookings,
       ROUND(SUM(v.revenue),2) AS revenue,
       ROUND(SUM(v.revenue)*100/SUM(SUM(v.revenue)) OVER (),1) AS pct_of_total,
       RANK() OVER (ORDER BY SUM(v.revenue) DESC) AS mechanic_rank
FROM v_booking_revenue v
LEFT JOIN mechanics m ON m.mechanic_id=v.mechanic_id
WHERE v.status='Completed'
GROUP BY m.mechanic_id,m.mechanic_name
ORDER BY revenue DESC;

-- 7.9 Revenue by customer city (COALESCE for unknown city)
SELECT COALESCE(c.city,'Unknown') AS city,
       COUNT(DISTINCT c.customer_id) AS customers,
       ROUND(SUM(v.revenue),2) AS revenue
FROM v_booking_revenue v
JOIN vehicles vh ON vh.vehicle_id=v.vehicle_id
JOIN customers c ON c.customer_id=vh.customer_id
WHERE v.status='Completed'
GROUP BY COALESCE(c.city,'Unknown')
ORDER BY revenue DESC;

-- 7.10 Payment mode mix
SELECT payment_mode,COUNT(*) AS bookings,
       ROUND(COUNT(*)*100/SUM(COUNT(*)) OVER (),1) AS pct_bookings
FROM service_bookings
GROUP BY payment_mode
ORDER BY bookings DESC;


/* =====================================================================
   PART 8 — PRACTICE EXERCISES (answers below each question)
   ===================================================================== */

-- Q1. List customers whose email domain is gmail.com, names in UPPER case.
SELECT UPPER(full_name) AS customer_name,email
FROM customers
WHERE SUBSTRING_INDEX(email,'@',-1)='gmail.com';

-- Q2. Which spare parts were used more than 5 units in total? (HAVING)
SELECT p.part_name,SUM(bp.quantity) AS units_used
FROM booking_parts bp
JOIN parts p ON p.part_id=bp.part_id
GROUP BY p.part_name
HAVING SUM(bp.quantity)>5;

-- Q3. Show each supervisor and how many mechanics report to them (self join).
SELECT s.mechanic_name AS supervisor,COUNT(m.mechanic_id) AS direct_reports
FROM mechanics s
LEFT JOIN mechanics m ON m.supervisor_id=s.mechanic_id
GROUP BY s.mechanic_id,s.mechanic_name
HAVING COUNT(m.mechanic_id)>0;

-- Q4. Customers in Coimbatore who did NOT book a service in Q3 2025 (Jul-Sep).
SELECT c.full_name
FROM customers c
WHERE c.city='Coimbatore'
  AND NOT EXISTS (
      SELECT 1
      FROM vehicles vh
      JOIN service_bookings b ON b.vehicle_id=vh.vehicle_id
      WHERE vh.customer_id=c.customer_id
        AND b.booking_date>='2025-07-01'
        AND b.booking_date<'2025-10-01'
  );

-- Q5. Each vehicle's first-ever service booking and its value (ROW_NUMBER).
WITH first_booking AS (
    SELECT v.*,
           ROW_NUMBER() OVER (
               PARTITION BY vehicle_id ORDER BY booking_date
           ) AS rn
    FROM v_booking_revenue v
)
SELECT vehicle_id,booking_id,DATE(booking_date) AS first_booking,revenue
FROM first_booking
WHERE rn=1;

-- Q6. Service category with the highest average discount given.
SELECT st.service_category,ROUND(AVG(t.discount_pct),2) AS avg_discount
FROM service_tasks t
JOIN service_types st ON st.service_type_id=t.service_type_id
GROUP BY st.service_category
ORDER BY avg_discount DESC
LIMIT 1;

-- =====================================================================
-- END OF SCRIPT
-- Suggested student tasks:
-- 1. Change Top 2 to Top 3 in the window-function queries.
-- 2. Replace RANK() with DENSE_RANK() and compare results.
-- 3. Add another mechanic and insert more service bookings.
-- 4. Calculate each mechanic's total revenue, then rank mechanics
--    within each specialization.
-- =====================================================================
