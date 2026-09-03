# Database Design

## Overview

The College Management System uses **MySQL 8.x** with a logical database-per-service pattern.

## Database List

- `college_auth` — Authentication, users, roles, permissions
- `college_student` — Student domain data
- `college_teacher` — Teacher domain data
- `college_admin` — Academic structures (departments, courses, subjects, classes, timetables, exams, fees)
- `college_notification` — Notifications and announcements
- `college_file` — File metadata
- `college_audit` — Audit logs

## Entity Relationship Overview

```
┌─────────────┐
│    users    │──┐
└─────────────┘  │
                 │
     ┌───────────┼───────────┐
     ▼           ▼           ▼
┌──────────┐┌──────────┐┌──────────┐
│ students ││ teachers ││  admins  │
└─────┬────┘└────┬─────┘└──────────┘
      │          │
      │          │    ┌─────────────┐
      │          └────│ assignments │
      │               └─────────────┘
      │
      │    ┌──────────────────┐
      └────│ student_         │
           │ enrollments      │
           └──────────────────┘
                  │
                  ▼
           ┌──────────────┐
           │   courses    │◀──────┐
           └──────┬───────┘       │
                  │               │
                  ▼               │
           ┌──────────────┐       │
           │  departments │       │
           └──────────────┘       │
                                  │
           ┌──────────────┐       │
           │   subjects   │───────┘
           └──────┬───────┘
                  │
                  ▼
           ┌──────────────┐
           │  timetables  │
           └──────────────┘
```

---

## college_auth Database

### users

Stores all system users (students, teachers, admins).

| Column                | Type                                                                  | Constraints                                           | Description            |
| --------------------- | --------------------------------------------------------------------- | ----------------------------------------------------- | ---------------------- |
| id                    | BIGINT UNSIGNED                                                       | PRIMARY KEY, AUTO_INCREMENT                           | User ID                |
| email                 | VARCHAR(255)                                                          | UNIQUE, NOT NULL                                      | Email address          |
| password_hash         | VARCHAR(255)                                                          | NOT NULL                                              | Argon2 hashed password |
| role                  | ENUM('STUDENT','TEACHER','ADMIN')                                     | NOT NULL                                              | User role              |
| status                | ENUM('PENDING','APPROVED','ACTIVE','REJECTED','SUSPENDED','INACTIVE') | NOT NULL, DEFAULT 'PENDING'                           | Account status         |
| last_login_at         | TIMESTAMP                                                             | NULL                                                  | Last successful login  |
| failed_login_attempts | TINYINT UNSIGNED                                                      | DEFAULT 0                                             | Failed login counter   |
| locked_until          | TIMESTAMP                                                             | NULL                                                  | Account lockout expiry |
| created_at            | TIMESTAMP                                                             | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp     |
| updated_at            | TIMESTAMP                                                             | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp       |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (email)
- INDEX (role, status)

---

### roles

Predefined roles in the system.

| Column      | Type         | Constraints                 | Description        |
| ----------- | ------------ | --------------------------- | ------------------ |
| id          | INT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT | Role ID            |
| name        | VARCHAR(50)  | UNIQUE, NOT NULL            | Role name          |
| description | TEXT         | NULL                        | Role description   |
| created_at  | TIMESTAMP    | DEFAULT CURRENT_TIMESTAMP   | Creation timestamp |

**Seed Data:**

```sql
INSERT INTO roles (name, description) VALUES
('STUDENT', 'Student role with limited permissions'),
('TEACHER', 'Teacher role with classroom management permissions'),
('ADMIN', 'Administrator role with full system access');
```

---

### permissions

Granular permissions for authorization.

| Column      | Type         | Constraints                 | Description            |
| ----------- | ------------ | --------------------------- | ---------------------- |
| id          | INT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT | Permission ID          |
| name        | VARCHAR(100) | UNIQUE, NOT NULL            | Permission identifier  |
| resource    | VARCHAR(50)  | NOT NULL                    | Resource type          |
| action      | VARCHAR(50)  | NOT NULL                    | Action type            |
| description | TEXT         | NULL                        | Permission description |
| created_at  | TIMESTAMP    | DEFAULT CURRENT_TIMESTAMP   | Creation timestamp     |

**Examples:**

```sql
INSERT INTO permissions (name, resource, action, description) VALUES
('student:profile:read', 'student', 'read', 'View own student profile'),
('student:profile:update', 'student', 'update', 'Update own student profile'),
('teacher:attendance:create', 'attendance', 'create', 'Mark student attendance'),
('admin:student:delete', 'student', 'delete', 'Delete student records');
```

---

### user_roles

Many-to-many relationship between users and roles.

| Column      | Type            | Constraints                       | Description          |
| ----------- | --------------- | --------------------------------- | -------------------- |
| id          | BIGINT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT       | Record ID            |
| user_id     | BIGINT UNSIGNED | NOT NULL, FOREIGN KEY → users(id) | User reference       |
| role_id     | INT UNSIGNED    | NOT NULL, FOREIGN KEY → roles(id) | Role reference       |
| assigned_at | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP         | Assignment timestamp |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (user_id, role_id)
- INDEX (user_id)

---

### role_permissions

Many-to-many relationship between roles and permissions.

| Column        | Type         | Constraints                             | Description          |
| ------------- | ------------ | --------------------------------------- | -------------------- |
| id            | INT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT             | Record ID            |
| role_id       | INT UNSIGNED | NOT NULL, FOREIGN KEY → roles(id)       | Role reference       |
| permission_id | INT UNSIGNED | NOT NULL, FOREIGN KEY → permissions(id) | Permission reference |
| created_at    | TIMESTAMP    | DEFAULT CURRENT_TIMESTAMP               | Creation timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (role_id, permission_id)

---

### refresh_tokens

Active refresh tokens for JWT authentication.

| Column     | Type            | Constraints                       | Description          |
| ---------- | --------------- | --------------------------------- | -------------------- |
| id         | BIGINT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT       | Token ID             |
| user_id    | BIGINT UNSIGNED | NOT NULL, FOREIGN KEY → users(id) | User reference       |
| token_hash | VARCHAR(255)    | UNIQUE, NOT NULL                  | SHA256 hash of token |
| expires_at | TIMESTAMP       | NOT NULL                          | Expiration time      |
| revoked    | BOOLEAN         | DEFAULT FALSE                     | Revocation flag      |
| revoked_at | TIMESTAMP       | NULL                              | Revocation timestamp |
| created_at | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP         | Creation timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (token_hash)
- INDEX (user_id, revoked, expires_at)

**Cleanup:** Periodically delete expired/revoked tokens.

---

### password_reset_tokens

One-time password reset tokens.

| Column     | Type            | Constraints                       | Description                  |
| ---------- | --------------- | --------------------------------- | ---------------------------- |
| id         | BIGINT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT       | Token ID                     |
| user_id    | BIGINT UNSIGNED | NOT NULL, FOREIGN KEY → users(id) | User reference               |
| token_hash | VARCHAR(255)    | UNIQUE, NOT NULL                  | SHA256 hash of token         |
| expires_at | TIMESTAMP       | NOT NULL                          | Expiration time (15 minutes) |
| used       | BOOLEAN         | DEFAULT FALSE                     | Usage flag                   |
| used_at    | TIMESTAMP       | NULL                              | Usage timestamp              |
| created_at | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP         | Creation timestamp           |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (token_hash)
- INDEX (user_id, used, expires_at)

---

## college_student Database

### students

Student profiles and academic information.

| Column                 | Type                                                                               | Constraints                                            | Description            |
| ---------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------ | ---------------------- |
| id                     | BIGINT UNSIGNED                                                                    | PRIMARY KEY, AUTO_INCREMENT                            | Student ID             |
| user_id                | BIGINT UNSIGNED                                                                    | UNIQUE, NOT NULL, FOREIGN KEY → college_auth.users(id) | User reference         |
| student_id_number      | VARCHAR(20)                                                                        | UNIQUE, NOT NULL                                       | Student ID number      |
| first_name             | VARCHAR(100)                                                                       | NOT NULL                                               | First name             |
| last_name              | VARCHAR(100)                                                                       | NOT NULL                                               | Last name              |
| date_of_birth          | DATE                                                                               | NOT NULL                                               | Date of birth          |
| gender                 | ENUM('MALE','FEMALE','OTHER')                                                      | NOT NULL                                               | Gender                 |
| email                  | VARCHAR(255)                                                                       | UNIQUE, NOT NULL                                       | Email address          |
| phone                  | VARCHAR(20)                                                                        | NOT NULL                                               | Phone number           |
| alternate_phone        | VARCHAR(20)                                                                        | NULL                                                   | Alternate phone        |
| address_line1          | VARCHAR(255)                                                                       | NOT NULL                                               | Address line 1         |
| address_line2          | VARCHAR(255)                                                                       | NULL                                                   | Address line 2         |
| city                   | VARCHAR(100)                                                                       | NOT NULL                                               | City                   |
| state                  | VARCHAR(100)                                                                       | NOT NULL                                               | State                  |
| country                | VARCHAR(100)                                                                       | NOT NULL                                               | Country                |
| postal_code            | VARCHAR(20)                                                                        | NOT NULL                                               | Postal code            |
| guardian_name          | VARCHAR(200)                                                                       | NOT NULL                                               | Guardian name          |
| guardian_phone         | VARCHAR(20)                                                                        | NOT NULL                                               | Guardian phone         |
| guardian_email         | VARCHAR(255)                                                                       | NULL                                                   | Guardian email         |
| previous_qualification | VARCHAR(255)                                                                       | NULL                                                   | Previous qualification |
| department_id          | INT UNSIGNED                                                                       | NULL, FOREIGN KEY → college_admin.departments(id)      | Department reference   |
| course_id              | INT UNSIGNED                                                                       | NULL, FOREIGN KEY → college_admin.courses(id)          | Course reference       |
| admission_year         | YEAR                                                                               | NOT NULL                                               | Admission year         |
| current_semester       | TINYINT UNSIGNED                                                                   | DEFAULT 1                                              | Current semester       |
| profile_picture        | VARCHAR(255)                                                                       | NULL                                                   | Profile picture path   |
| status                 | ENUM('PENDING','APPROVED','ACTIVE','REJECTED','SUSPENDED','GRADUATED','WITHDRAWN') | NOT NULL, DEFAULT 'PENDING'                            | Student status         |
| created_at             | TIMESTAMP                                                                          | DEFAULT CURRENT_TIMESTAMP                              | Creation timestamp     |
| updated_at             | TIMESTAMP                                                                          | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP  | Update timestamp       |
| deleted_at             | TIMESTAMP                                                                          | NULL                                                   | Soft delete timestamp  |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (user_id)
- UNIQUE KEY (student_id_number)
- UNIQUE KEY (email)
- INDEX (department_id, course_id, current_semester)
- INDEX (status)

---

### student_enrollments

Student course enrollments per academic year.

| Column          | Type                                            | Constraints                                           | Description        |
| --------------- | ----------------------------------------------- | ----------------------------------------------------- | ------------------ |
| id              | BIGINT UNSIGNED                                 | PRIMARY KEY, AUTO_INCREMENT                           | Enrollment ID      |
| student_id      | BIGINT UNSIGNED                                 | NOT NULL, FOREIGN KEY → students(id)                  | Student reference  |
| course_id       | INT UNSIGNED                                    | NOT NULL, FOREIGN KEY → college_admin.courses(id)     | Course reference   |
| class_id        | INT UNSIGNED                                    | NULL, FOREIGN KEY → college_admin.classes(id)         | Class reference    |
| academic_year   | YEAR                                            | NOT NULL                                              | Academic year      |
| semester        | TINYINT UNSIGNED                                | NOT NULL                                              | Semester number    |
| enrollment_date | DATE                                            | NOT NULL                                              | Enrollment date    |
| status          | ENUM('ENROLLED','COMPLETED','DROPPED','FAILED') | NOT NULL, DEFAULT 'ENROLLED'                          | Enrollment status  |
| created_at      | TIMESTAMP                                       | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp |
| updated_at      | TIMESTAMP                                       | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (student_id, course_id, academic_year, semester)
- INDEX (student_id)
- INDEX (class_id)

---

### student_attendance

Daily attendance records for students.

| Column     | Type                                      | Constraints                                           | Description        |
| ---------- | ----------------------------------------- | ----------------------------------------------------- | ------------------ |
| id         | BIGINT UNSIGNED                           | PRIMARY KEY, AUTO_INCREMENT                           | Attendance ID      |
| student_id | BIGINT UNSIGNED                           | NOT NULL, FOREIGN KEY → students(id)                  | Student reference  |
| subject_id | INT UNSIGNED                              | NOT NULL, FOREIGN KEY → college_admin.subjects(id)    | Subject reference  |
| class_id   | INT UNSIGNED                              | NOT NULL, FOREIGN KEY → college_admin.classes(id)     | Class reference    |
| date       | DATE                                      | NOT NULL                                              | Attendance date    |
| status     | ENUM('PRESENT','ABSENT','LATE','EXCUSED') | NOT NULL                                              | Attendance status  |
| marked_by  | BIGINT UNSIGNED                           | NOT NULL, FOREIGN KEY → college_auth.users(id)        | Teacher who marked |
| notes      | TEXT                                      | NULL                                                  | Additional notes   |
| created_at | TIMESTAMP                                 | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp |
| updated_at | TIMESTAMP                                 | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (student_id, subject_id, date)
- INDEX (student_id, date)
- INDEX (class_id, date)
- INDEX (marked_by)

---

### student_fees

Fee records for students.

| Column              | Type                                               | Constraints                                              | Description             |
| ------------------- | -------------------------------------------------- | -------------------------------------------------------- | ----------------------- |
| id                  | BIGINT UNSIGNED                                    | PRIMARY KEY, AUTO_INCREMENT                              | Fee ID                  |
| student_id          | BIGINT UNSIGNED                                    | NOT NULL, FOREIGN KEY → students(id)                     | Student reference       |
| fee_structure_id    | INT UNSIGNED                                       | NOT NULL, FOREIGN KEY → college_admin.fee_structures(id) | Fee structure reference |
| academic_year       | YEAR                                               | NOT NULL                                                 | Academic year           |
| semester            | TINYINT UNSIGNED                                   | NOT NULL                                                 | Semester                |
| total_amount        | DECIMAL(10,2)                                      | NOT NULL                                                 | Total fee amount        |
| paid_amount         | DECIMAL(10,2)                                      | DEFAULT 0.00                                             | Amount paid             |
| discount_amount     | DECIMAL(10,2)                                      | DEFAULT 0.00                                             | Discount applied        |
| fine_amount         | DECIMAL(10,2)                                      | DEFAULT 0.00                                             | Late fee/fine           |
| due_date            | DATE                                               | NOT NULL                                                 | Payment due date        |
| status              | ENUM('UNPAID','PARTIAL','PAID','WAIVED','OVERDUE') | NOT NULL, DEFAULT 'UNPAID'                               | Payment status          |
| scholarship_applied | BOOLEAN                                            | DEFAULT FALSE                                            | Scholarship flag        |
| scholarship_amount  | DECIMAL(10,2)                                      | DEFAULT 0.00                                             | Scholarship amount      |
| created_at          | TIMESTAMP                                          | DEFAULT CURRENT_TIMESTAMP                                | Creation timestamp      |
| updated_at          | TIMESTAMP                                          | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP    | Update timestamp        |

**Indexes:**

- PRIMARY KEY (id)
- INDEX (student_id, academic_year, semester)
- INDEX (status, due_date)

---

### payments

Individual payment transactions.

| Column         | Type                                                             | Constraints                                | Description             |
| -------------- | ---------------------------------------------------------------- | ------------------------------------------ | ----------------------- |
| id             | BIGINT UNSIGNED                                                  | PRIMARY KEY, AUTO_INCREMENT                | Payment ID              |
| student_fee_id | BIGINT UNSIGNED                                                  | NOT NULL, FOREIGN KEY → student_fees(id)   | Fee reference           |
| amount         | DECIMAL(10,2)                                                    | NOT NULL                                   | Payment amount          |
| payment_date   | TIMESTAMP                                                        | NOT NULL                                   | Payment timestamp       |
| payment_method | ENUM('CASH','CARD','UPI','NET_BANKING','CHEQUE','BANK_TRANSFER') | NOT NULL                                   | Payment method          |
| transaction_id | VARCHAR(255)                                                     | NULL                                       | External transaction ID |
| receipt_number | VARCHAR(50)                                                      | UNIQUE, NOT NULL                           | Receipt number          |
| receipt_url    | VARCHAR(255)                                                     | NULL                                       | Receipt file path       |
| processed_by   | BIGINT UNSIGNED                                                  | NULL, FOREIGN KEY → college_auth.users(id) | Admin who processed     |
| notes          | TEXT                                                             | NULL                                       | Payment notes           |
| created_at     | TIMESTAMP                                                        | DEFAULT CURRENT_TIMESTAMP                  | Creation timestamp      |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (receipt_number)
- INDEX (student_fee_id)
- INDEX (payment_date)
- INDEX (transaction_id)

---

## college_teacher Database

### teachers

Teacher profiles and employment information.

| Column            | Type                                                                            | Constraints                                            | Description               |
| ----------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------ | ------------------------- |
| id                | BIGINT UNSIGNED                                                                 | PRIMARY KEY, AUTO_INCREMENT                            | Teacher ID                |
| user_id           | BIGINT UNSIGNED                                                                 | UNIQUE, NOT NULL, FOREIGN KEY → college_auth.users(id) | User reference            |
| teacher_id_number | VARCHAR(20)                                                                     | UNIQUE, NOT NULL                                       | Teacher ID number         |
| first_name        | VARCHAR(100)                                                                    | NOT NULL                                               | First name                |
| last_name         | VARCHAR(100)                                                                    | NOT NULL                                               | Last name                 |
| email             | VARCHAR(255)                                                                    | UNIQUE, NOT NULL                                       | Email address             |
| phone             | VARCHAR(20)                                                                     | NOT NULL                                               | Phone number              |
| date_of_birth     | DATE                                                                            | NOT NULL                                               | Date of birth             |
| gender            | ENUM('MALE','FEMALE','OTHER')                                                   | NOT NULL                                               | Gender                    |
| address_line1     | VARCHAR(255)                                                                    | NOT NULL                                               | Address line 1            |
| address_line2     | VARCHAR(255)                                                                    | NULL                                                   | Address line 2            |
| city              | VARCHAR(100)                                                                    | NOT NULL                                               | City                      |
| state             | VARCHAR(100)                                                                    | NOT NULL                                               | State                     |
| country           | VARCHAR(100)                                                                    | NOT NULL                                               | Country                   |
| postal_code       | VARCHAR(20)                                                                     | NOT NULL                                               | Postal code               |
| qualification     | VARCHAR(255)                                                                    | NOT NULL                                               | Educational qualification |
| specialization    | VARCHAR(255)                                                                    | NULL                                                   | Area of specialization    |
| experience_years  | TINYINT UNSIGNED                                                                | DEFAULT 0                                              | Years of experience       |
| department_id     | INT UNSIGNED                                                                    | NULL, FOREIGN KEY → college_admin.departments(id)      | Department reference      |
| designation       | VARCHAR(100)                                                                    | NULL                                                   | Job designation           |
| joining_date      | DATE                                                                            | NOT NULL                                               | Joining date              |
| profile_picture   | VARCHAR(255)                                                                    | NULL                                                   | Profile picture path      |
| status            | ENUM('PENDING','APPROVED','ACTIVE','REJECTED','SUSPENDED','RESIGNED','RETIRED') | NOT NULL, DEFAULT 'PENDING'                            | Teacher status            |
| created_at        | TIMESTAMP                                                                       | DEFAULT CURRENT_TIMESTAMP                              | Creation timestamp        |
| updated_at        | TIMESTAMP                                                                       | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP  | Update timestamp          |
| deleted_at        | TIMESTAMP                                                                       | NULL                                                   | Soft delete timestamp     |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (user_id)
- UNIQUE KEY (teacher_id_number)
- UNIQUE KEY (email)
- INDEX (department_id)
- INDEX (status)

---

### teacher_assignments

Teacher assignments to subjects and classes.

| Column        | Type             | Constraints                                           | Description        |
| ------------- | ---------------- | ----------------------------------------------------- | ------------------ |
| id            | BIGINT UNSIGNED  | PRIMARY KEY, AUTO_INCREMENT                           | Assignment ID      |
| teacher_id    | BIGINT UNSIGNED  | NOT NULL, FOREIGN KEY → teachers(id)                  | Teacher reference  |
| subject_id    | INT UNSIGNED     | NOT NULL, FOREIGN KEY → college_admin.subjects(id)    | Subject reference  |
| class_id      | INT UNSIGNED     | NOT NULL, FOREIGN KEY → college_admin.classes(id)     | Class reference    |
| academic_year | YEAR             | NOT NULL                                              | Academic year      |
| semester      | TINYINT UNSIGNED | NOT NULL                                              | Semester           |
| assigned_date | DATE             | NOT NULL                                              | Assignment date    |
| is_active     | BOOLEAN          | DEFAULT TRUE                                          | Active flag        |
| created_at    | TIMESTAMP        | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp |
| updated_at    | TIMESTAMP        | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (teacher_id, subject_id, class_id, academic_year, semester)
- INDEX (teacher_id, is_active)
- INDEX (class_id, subject_id)

---

### teacher_attendance

Teacher attendance records.

| Column     | Type                                                            | Constraints                                           | Description              |
| ---------- | --------------------------------------------------------------- | ----------------------------------------------------- | ------------------------ |
| id         | BIGINT UNSIGNED                                                 | PRIMARY KEY, AUTO_INCREMENT                           | Attendance ID            |
| teacher_id | BIGINT UNSIGNED                                                 | NOT NULL, FOREIGN KEY → teachers(id)                  | Teacher reference        |
| date       | DATE                                                            | NOT NULL                                              | Attendance date          |
| status     | ENUM('PRESENT','ABSENT','HALF_DAY','LEAVE','HOLIDAY')           | NOT NULL                                              | Attendance status        |
| leave_type | ENUM('SICK','CASUAL','EARNED','MATERNITY','PATERNITY','UNPAID') | NULL                                                  | Leave type if applicable |
| marked_at  | TIMESTAMP                                                       | DEFAULT CURRENT_TIMESTAMP                             | Marking timestamp        |
| notes      | TEXT                                                            | NULL                                                  | Additional notes         |
| created_at | TIMESTAMP                                                       | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp       |
| updated_at | TIMESTAMP                                                       | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp         |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (teacher_id, date)
- INDEX (teacher_id, date)
- INDEX (date, status)

---

### assignments

Assignments created by teachers.

| Column       | Type            | Constraints                                           | Description            |
| ------------ | --------------- | ----------------------------------------------------- | ---------------------- |
| id           | BIGINT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT                           | Assignment ID          |
| teacher_id   | BIGINT UNSIGNED | NOT NULL, FOREIGN KEY → teachers(id)                  | Teacher reference      |
| subject_id   | INT UNSIGNED    | NOT NULL, FOREIGN KEY → college_admin.subjects(id)    | Subject reference      |
| class_id     | INT UNSIGNED    | NOT NULL, FOREIGN KEY → college_admin.classes(id)     | Class reference        |
| title        | VARCHAR(255)    | NOT NULL                                              | Assignment title       |
| description  | TEXT            | NOT NULL                                              | Assignment description |
| due_date     | TIMESTAMP       | NOT NULL                                              | Submission deadline    |
| max_marks    | DECIMAL(5,2)    | NULL                                                  | Maximum marks          |
| attachments  | JSON            | NULL                                                  | Attachment file paths  |
| is_published | BOOLEAN         | DEFAULT TRUE                                          | Published flag         |
| created_at   | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp     |
| updated_at   | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp       |
| deleted_at   | TIMESTAMP       | NULL                                                  | Soft delete timestamp  |

**Indexes:**

- PRIMARY KEY (id)
- INDEX (teacher_id, class_id, subject_id)
- INDEX (due_date)

---

### assignment_submissions

Student submissions for assignments.

| Column          | Type                                         | Constraints                                           | Description          |
| --------------- | -------------------------------------------- | ----------------------------------------------------- | -------------------- |
| id              | BIGINT UNSIGNED                              | PRIMARY KEY, AUTO_INCREMENT                           | Submission ID        |
| assignment_id   | BIGINT UNSIGNED                              | NOT NULL, FOREIGN KEY → assignments(id)               | Assignment reference |
| student_id      | BIGINT UNSIGNED                              | NOT NULL, FOREIGN KEY → college_student.students(id)  | Student reference    |
| submission_date | TIMESTAMP                                    | NOT NULL                                              | Submission timestamp |
| attachments     | JSON                                         | NULL                                                  | Submitted file paths |
| remarks         | TEXT                                         | NULL                                                  | Student remarks      |
| feedback        | TEXT                                         | NULL                                                  | Teacher feedback     |
| marks_obtained  | DECIMAL(5,2)                                 | NULL                                                  | Marks awarded        |
| graded_at       | TIMESTAMP                                    | NULL                                                  | Grading timestamp    |
| graded_by       | BIGINT UNSIGNED                              | NULL, FOREIGN KEY → teachers(id)                      | Teacher who graded   |
| status          | ENUM('SUBMITTED','GRADED','LATE','RESUBMIT') | NOT NULL, DEFAULT 'SUBMITTED'                         | Submission status    |
| created_at      | TIMESTAMP                                    | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp   |
| updated_at      | TIMESTAMP                                    | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp     |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (assignment_id, student_id)
- INDEX (assignment_id, status)
- INDEX (student_id)

---

## college_admin Database

### departments

Academic departments.

| Column           | Type            | Constraints                                           | Description            |
| ---------------- | --------------- | ----------------------------------------------------- | ---------------------- |
| id               | INT UNSIGNED    | PRIMARY KEY, AUTO_INCREMENT                           | Department ID          |
| name             | VARCHAR(200)    | UNIQUE, NOT NULL                                      | Department name        |
| code             | VARCHAR(20)     | UNIQUE, NOT NULL                                      | Department code        |
| description      | TEXT            | NULL                                                  | Department description |
| head_id          | BIGINT UNSIGNED | NULL, FOREIGN KEY → college_teacher.teachers(id)      | Department head        |
| established_date | DATE            | NULL                                                  | Establishment date     |
| is_active        | BOOLEAN         | DEFAULT TRUE                                          | Active flag            |
| created_at       | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp     |
| updated_at       | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp       |
| deleted_at       | TIMESTAMP       | NULL                                                  | Soft delete timestamp  |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (name)
- UNIQUE KEY (code)
- INDEX (is_active)

---

### courses

Academic courses/programs.

| Column          | Type              | Constraints                                           | Description              |
| --------------- | ----------------- | ----------------------------------------------------- | ------------------------ |
| id              | INT UNSIGNED      | PRIMARY KEY, AUTO_INCREMENT                           | Course ID                |
| name            | VARCHAR(200)      | NOT NULL                                              | Course name              |
| code            | VARCHAR(20)       | UNIQUE, NOT NULL                                      | Course code              |
| department_id   | INT UNSIGNED      | NOT NULL, FOREIGN KEY → departments(id)               | Department reference     |
| duration_years  | TINYINT UNSIGNED  | NOT NULL                                              | Course duration in years |
| total_semesters | TINYINT UNSIGNED  | NOT NULL                                              | Total semesters          |
| total_credits   | SMALLINT UNSIGNED | NULL                                                  | Total credits required   |
| description     | TEXT              | NULL                                                  | Course description       |
| is_active       | BOOLEAN           | DEFAULT TRUE                                          | Active flag              |
| created_at      | TIMESTAMP         | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp       |
| updated_at      | TIMESTAMP         | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp         |
| deleted_at      | TIMESTAMP         | NULL                                                  | Soft delete timestamp    |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (code)
- INDEX (department_id, is_active)

---

### subjects

Academic subjects.

| Column      | Type             | Constraints                                           | Description           |
| ----------- | ---------------- | ----------------------------------------------------- | --------------------- |
| id          | INT UNSIGNED     | PRIMARY KEY, AUTO_INCREMENT                           | Subject ID            |
| name        | VARCHAR(200)     | NOT NULL                                              | Subject name          |
| code        | VARCHAR(20)      | UNIQUE, NOT NULL                                      | Subject code          |
| course_id   | INT UNSIGNED     | NOT NULL, FOREIGN KEY → courses(id)                   | Course reference      |
| semester    | TINYINT UNSIGNED | NOT NULL                                              | Semester number       |
| credits     | TINYINT UNSIGNED | NOT NULL                                              | Credit hours          |
| description | TEXT             | NULL                                                  | Subject description   |
| is_elective | BOOLEAN          | DEFAULT FALSE                                         | Elective flag         |
| is_active   | BOOLEAN          | DEFAULT TRUE                                          | Active flag           |
| created_at  | TIMESTAMP        | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp    |
| updated_at  | TIMESTAMP        | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp      |
| deleted_at  | TIMESTAMP        | NULL                                                  | Soft delete timestamp |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (code)
- INDEX (course_id, semester, is_active)

---

### classes

Class sections for organizing students.

| Column           | Type              | Constraints                                           | Description             |
| ---------------- | ----------------- | ----------------------------------------------------- | ----------------------- |
| id               | INT UNSIGNED      | PRIMARY KEY, AUTO_INCREMENT                           | Class ID                |
| course_id        | INT UNSIGNED      | NOT NULL, FOREIGN KEY → courses(id)                   | Course reference        |
| semester         | TINYINT UNSIGNED  | NOT NULL                                              | Semester number         |
| section          | VARCHAR(10)       | NOT NULL                                              | Section (A, B, C, etc.) |
| academic_year    | YEAR              | NOT NULL                                              | Academic year           |
| room_id          | INT UNSIGNED      | NULL, FOREIGN KEY → rooms(id)                         | Default room reference  |
| class_teacher_id | BIGINT UNSIGNED   | NULL, FOREIGN KEY → college_teacher.teachers(id)      | Class teacher           |
| max_students     | SMALLINT UNSIGNED | DEFAULT 60                                            | Maximum students        |
| created_at       | TIMESTAMP         | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp      |
| updated_at       | TIMESTAMP         | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp        |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (course_id, semester, section, academic_year)
- INDEX (academic_year, course_id)

---

### rooms

Classrooms and facilities.

| Column       | Type                                                    | Constraints                                           | Description          |
| ------------ | ------------------------------------------------------- | ----------------------------------------------------- | -------------------- |
| id           | INT UNSIGNED                                            | PRIMARY KEY, AUTO_INCREMENT                           | Room ID              |
| room_number  | VARCHAR(20)                                             | UNIQUE, NOT NULL                                      | Room number          |
| building     | VARCHAR(100)                                            | NULL                                                  | Building name        |
| floor        | TINYINT                                                 | NULL                                                  | Floor number         |
| capacity     | SMALLINT UNSIGNED                                       | NOT NULL                                              | Seating capacity     |
| room_type    | ENUM('CLASSROOM','LAB','AUDITORIUM','LIBRARY','OFFICE') | NOT NULL                                              | Room type            |
| facilities   | JSON                                                    | NULL                                                  | Available facilities |
| is_available | BOOLEAN                                                 | DEFAULT TRUE                                          | Availability flag    |
| created_at   | TIMESTAMP                                               | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp   |
| updated_at   | TIMESTAMP                                               | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp     |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (room_number)
- INDEX (room_type, is_available)

---

### timetables

Class schedules.

| Column        | Type                                                                         | Constraints                                           | Description        |
| ------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------ |
| id            | BIGINT UNSIGNED                                                              | PRIMARY KEY, AUTO_INCREMENT                           | Timetable ID       |
| class_id      | INT UNSIGNED                                                                 | NOT NULL, FOREIGN KEY → classes(id)                   | Class reference    |
| subject_id    | INT UNSIGNED                                                                 | NOT NULL, FOREIGN KEY → subjects(id)                  | Subject reference  |
| teacher_id    | BIGINT UNSIGNED                                                              | NOT NULL, FOREIGN KEY → college_teacher.teachers(id)  | Teacher reference  |
| day_of_week   | ENUM('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY') | NOT NULL                                              | Day of week        |
| start_time    | TIME                                                                         | NOT NULL                                              | Start time         |
| end_time      | TIME                                                                         | NOT NULL                                              | End time           |
| room_id       | INT UNSIGNED                                                                 | NULL, FOREIGN KEY → rooms(id)                         | Room reference     |
| academic_year | YEAR                                                                         | NOT NULL                                              | Academic year      |
| semester      | TINYINT UNSIGNED                                                             | NOT NULL                                              | Semester           |
| is_active     | BOOLEAN                                                                      | DEFAULT TRUE                                          | Active flag        |
| created_at    | TIMESTAMP                                                                    | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp |
| updated_at    | TIMESTAMP                                                                    | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (class_id, subject_id, day_of_week, start_time, academic_year, semester)
- INDEX (teacher_id, day_of_week, start_time)
- INDEX (room_id, day_of_week, start_time)

**Conflict Detection:**

- Teacher cannot have overlapping schedules
- Room cannot have overlapping schedules

---

### examinations

Examination schedules.

| Column        | Type                                                      | Constraints                                           | Description        |
| ------------- | --------------------------------------------------------- | ----------------------------------------------------- | ------------------ |
| id            | INT UNSIGNED                                              | PRIMARY KEY, AUTO_INCREMENT                           | Exam ID            |
| name          | VARCHAR(200)                                              | NOT NULL                                              | Exam name          |
| exam_type     | ENUM('INTERNAL','MID_TERM','END_TERM','PRACTICAL','VIVA') | NOT NULL                                              | Exam type          |
| course_id     | INT UNSIGNED                                              | NOT NULL, FOREIGN KEY → courses(id)                   | Course reference   |
| semester      | TINYINT UNSIGNED                                          | NOT NULL                                              | Semester           |
| academic_year | YEAR                                                      | NOT NULL                                              | Academic year      |
| start_date    | DATE                                                      | NOT NULL                                              | Exam start date    |
| end_date      | DATE                                                      | NOT NULL                                              | Exam end date      |
| is_published  | BOOLEAN                                                   | DEFAULT FALSE                                         | Published flag     |
| created_at    | TIMESTAMP                                                 | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp |
| updated_at    | TIMESTAMP                                                 | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- INDEX (course_id, semester, academic_year)
- INDEX (start_date, end_date)

---

### examination_schedules

Individual exam subject schedules.

| Column         | Type         | Constraints                                           | Description           |
| -------------- | ------------ | ----------------------------------------------------- | --------------------- |
| id             | INT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT                           | Schedule ID           |
| examination_id | INT UNSIGNED | NOT NULL, FOREIGN KEY → examinations(id)              | Examination reference |
| subject_id     | INT UNSIGNED | NOT NULL, FOREIGN KEY → subjects(id)                  | Subject reference     |
| exam_date      | DATE         | NOT NULL                                              | Exam date             |
| start_time     | TIME         | NOT NULL                                              | Start time            |
| end_time       | TIME         | NOT NULL                                              | End time              |
| room_id        | INT UNSIGNED | NULL, FOREIGN KEY → rooms(id)                         | Room reference        |
| max_marks      | DECIMAL(5,2) | NOT NULL                                              | Maximum marks         |
| created_at     | TIMESTAMP    | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp    |
| updated_at     | TIMESTAMP    | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp      |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (examination_id, subject_id)
- INDEX (exam_date, start_time)

---

### marks

Student marks for examinations.

| Column                  | Type            | Constraints                                           | Description             |
| ----------------------- | --------------- | ----------------------------------------------------- | ----------------------- |
| id                      | BIGINT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT                           | Marks ID                |
| student_id              | BIGINT UNSIGNED | NOT NULL, FOREIGN KEY → college_student.students(id)  | Student reference       |
| subject_id              | INT UNSIGNED    | NOT NULL, FOREIGN KEY → subjects(id)                  | Subject reference       |
| examination_schedule_id | INT UNSIGNED    | NOT NULL, FOREIGN KEY → examination_schedules(id)     | Exam schedule reference |
| marks_obtained          | DECIMAL(5,2)    | NOT NULL                                              | Marks obtained          |
| max_marks               | DECIMAL(5,2)    | NOT NULL                                              | Maximum marks           |
| grade                   | VARCHAR(5)      | NULL                                                  | Grade (A+, A, B+, etc.) |
| remarks                 | TEXT            | NULL                                                  | Remarks                 |
| entered_by              | BIGINT UNSIGNED | NOT NULL, FOREIGN KEY → college_auth.users(id)        | Teacher who entered     |
| is_finalized            | BOOLEAN         | DEFAULT FALSE                                         | Finalized flag          |
| finalized_at            | TIMESTAMP       | NULL                                                  | Finalization timestamp  |
| created_at              | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp      |
| updated_at              | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp        |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (student_id, examination_schedule_id)
- INDEX (student_id, subject_id)
- INDEX (entered_by)

---

### fee_structures

Fee structure templates per course and semester.

| Column        | Type             | Constraints                                           | Description        |
| ------------- | ---------------- | ----------------------------------------------------- | ------------------ |
| id            | INT UNSIGNED     | PRIMARY KEY, AUTO_INCREMENT                           | Fee structure ID   |
| course_id     | INT UNSIGNED     | NOT NULL, FOREIGN KEY → courses(id)                   | Course reference   |
| semester      | TINYINT UNSIGNED | NOT NULL                                              | Semester           |
| academic_year | YEAR             | NOT NULL                                              | Academic year      |
| tuition_fee   | DECIMAL(10,2)    | NOT NULL                                              | Tuition fee        |
| library_fee   | DECIMAL(10,2)    | DEFAULT 0.00                                          | Library fee        |
| lab_fee       | DECIMAL(10,2)    | DEFAULT 0.00                                          | Lab fee            |
| exam_fee      | DECIMAL(10,2)    | DEFAULT 0.00                                          | Exam fee           |
| sports_fee    | DECIMAL(10,2)    | DEFAULT 0.00                                          | Sports fee         |
| other_fee     | DECIMAL(10,2)    | DEFAULT 0.00                                          | Other fees         |
| total_fee     | DECIMAL(10,2)    | NOT NULL                                              | Total fee          |
| created_at    | TIMESTAMP        | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp |
| updated_at    | TIMESTAMP        | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (course_id, semester, academic_year)
- INDEX (course_id, academic_year)

---

## college_notification Database

### notifications

User notifications.

| Column     | Type            | Constraints                                    | Description          |
| ---------- | --------------- | ---------------------------------------------- | -------------------- |
| id         | BIGINT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT                    | Notification ID      |
| user_id    | BIGINT UNSIGNED | NOT NULL, FOREIGN KEY → college_auth.users(id) | User reference       |
| type       | VARCHAR(50)     | NOT NULL                                       | Notification type    |
| title      | VARCHAR(255)    | NOT NULL                                       | Notification title   |
| message    | TEXT            | NOT NULL                                       | Notification message |
| data       | JSON            | NULL                                           | Additional data      |
| is_read    | BOOLEAN         | DEFAULT FALSE                                  | Read flag            |
| read_at    | TIMESTAMP       | NULL                                           | Read timestamp       |
| created_at | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP                      | Creation timestamp   |

**Indexes:**

- PRIMARY KEY (id)
- INDEX (user_id, is_read, created_at DESC)
- INDEX (created_at)

**Types:**

- REGISTRATION_SUCCESS
- APPROVAL_SUCCESS
- REJECTION_NOTICE
- SUSPENSION_NOTICE
- ATTENDANCE_LOW
- MARKS_PUBLISHED
- ASSIGNMENT_CREATED
- ASSIGNMENT_GRADED
- FEE_DUE
- FEE_OVERDUE
- EXAM_SCHEDULED
- ANNOUNCEMENT

---

### announcements

System-wide announcements.

| Column               | Type                                    | Constraints                                           | Description           |
| -------------------- | --------------------------------------- | ----------------------------------------------------- | --------------------- |
| id                   | INT UNSIGNED                            | PRIMARY KEY, AUTO_INCREMENT                           | Announcement ID       |
| title                | VARCHAR(255)                            | NOT NULL                                              | Announcement title    |
| content              | TEXT                                    | NOT NULL                                              | Announcement content  |
| target_role          | ENUM('ALL','STUDENT','TEACHER','ADMIN') | DEFAULT 'ALL'                                         | Target role           |
| target_department_id | INT UNSIGNED                            | NULL, FOREIGN KEY → college_admin.departments(id)     | Target department     |
| target_course_id     | INT UNSIGNED                            | NULL, FOREIGN KEY → college_admin.courses(id)         | Target course         |
| priority             | ENUM('LOW','NORMAL','HIGH','URGENT')    | DEFAULT 'NORMAL'                                      | Priority              |
| published_at         | TIMESTAMP                               | NULL                                                  | Publication timestamp |
| expires_at           | TIMESTAMP                               | NULL                                                  | Expiration timestamp  |
| created_by           | BIGINT UNSIGNED                         | NOT NULL, FOREIGN KEY → college_auth.users(id)        | Creator reference     |
| created_at           | TIMESTAMP                               | DEFAULT CURRENT_TIMESTAMP                             | Creation timestamp    |
| updated_at           | TIMESTAMP                               | DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | Update timestamp      |

**Indexes:**

- PRIMARY KEY (id)
- INDEX (target_role, published_at, expires_at)
- INDEX (created_by)

---

## college_file Database

### files

File metadata for uploads.

| Column            | Type            | Constraints                                    | Description            |
| ----------------- | --------------- | ---------------------------------------------- | ---------------------- |
| id                | BIGINT UNSIGNED | PRIMARY KEY, AUTO_INCREMENT                    | File ID                |
| user_id           | BIGINT UNSIGNED | NOT NULL, FOREIGN KEY → college_auth.users(id) | Uploader reference     |
| filename          | VARCHAR(255)    | NOT NULL                                       | Stored filename (UUID) |
| original_filename | VARCHAR(255)    | NOT NULL                                       | Original filename      |
| mime_type         | VARCHAR(100)    | NOT NULL                                       | MIME type              |
| size_bytes        | BIGINT UNSIGNED | NOT NULL                                       | File size              |
| path              | VARCHAR(500)    | NOT NULL                                       | Storage path           |
| entity_type       | VARCHAR(50)     | NULL                                           | Related entity type    |
| entity_id         | BIGINT UNSIGNED | NULL                                           | Related entity ID      |
| is_public         | BOOLEAN         | DEFAULT FALSE                                  | Public access flag     |
| created_at        | TIMESTAMP       | DEFAULT CURRENT_TIMESTAMP                      | Upload timestamp       |

**Indexes:**

- PRIMARY KEY (id)
- UNIQUE KEY (filename)
- INDEX (user_id)
- INDEX (entity_type, entity_id)

**Allowed MIME Types:**

- image/jpeg, image/png, image/gif (profile pictures)
- application/pdf (documents)
- application/msword, application/vnd.openxmlformats-officedocument.wordprocessingml.document (Word)
- application/vnd.ms-powerpoint, application/vnd.openxmlformats-officedocument.presentationml.presentation (PPT)

---

## college_audit Database

### audit_logs

Audit trail for all important actions.

| Column         | Type                                       | Constraints                                | Description               |
| -------------- | ------------------------------------------ | ------------------------------------------ | ------------------------- |
| id             | BIGINT UNSIGNED                            | PRIMARY KEY, AUTO_INCREMENT                | Log ID                    |
| user_id        | BIGINT UNSIGNED                            | NULL, FOREIGN KEY → college_auth.users(id) | User who performed action |
| user_role      | ENUM('STUDENT','TEACHER','ADMIN','SYSTEM') | NOT NULL                                   | User role                 |
| action         | VARCHAR(100)                               | NOT NULL                                   | Action performed          |
| entity_type    | VARCHAR(50)                                | NOT NULL                                   | Entity type affected      |
| entity_id      | BIGINT UNSIGNED                            | NULL                                       | Entity ID affected        |
| old_value      | JSON                                       | NULL                                       | Previous value            |
| new_value      | JSON                                       | NULL                                       | New value                 |
| ip_address     | VARCHAR(45)                                | NULL                                       | IP address                |
| user_agent     | VARCHAR(500)                               | NULL                                       | User agent string         |
| correlation_id | VARCHAR(100)                               | NULL                                       | Request correlation ID    |
| created_at     | TIMESTAMP                                  | DEFAULT CURRENT_TIMESTAMP                  | Action timestamp          |

**Indexes:**

- PRIMARY KEY (id)
- INDEX (user_id, created_at)
- INDEX (entity_type, entity_id)
- INDEX (action, created_at)
- INDEX (correlation_id)
- INDEX (created_at)

**Actions:**

- LOGIN, LOGOUT, FAILED_LOGIN
- STUDENT_REGISTER, STUDENT_APPROVE, STUDENT_REJECT, STUDENT_SUSPEND
- TEACHER_REGISTER, TEACHER_APPROVE, TEACHER_REJECT, TEACHER_SUSPEND
- PROFILE_UPDATE
- ATTENDANCE_MARK, ATTENDANCE_UPDATE
- MARKS_CREATE, MARKS_UPDATE, MARKS_FINALIZE
- FEE_PAYMENT
- ASSIGNMENT_CREATE, ASSIGNMENT_UPDATE, ASSIGNMENT_DELETE
- COURSE_CREATE, COURSE_UPDATE, COURSE_DELETE
- SUBJECT_CREATE, SUBJECT_UPDATE, SUBJECT_DELETE
- DEPARTMENT_CREATE, DEPARTMENT_UPDATE, DEPARTMENT_DELETE

---

## Database Initialization

### Migration Strategy

1. Use TypeORM migrations for all schema changes
2. Never use `synchronize: true` in production
3. Version all migrations
4. Include rollback scripts

### Seed Data

Provide seed scripts for:

1. Roles and permissions
2. Sample departments (CS, IT, Mech, Civil, Electrical, Electronics)
3. Sample courses
4. Sample subjects
5. Sample admin user (username: admin@college.edu, password: Admin@123)
6. Sample rooms

### Backup Strategy

- Daily automated backups
- Point-in-time recovery capability
- Backup retention: 30 days

### Performance Considerations

- Add indexes on foreign keys
- Add composite indexes on frequently queried combinations
- Use EXPLAIN to analyze slow queries
- Implement database connection pooling
- Consider read replicas for reporting queries
