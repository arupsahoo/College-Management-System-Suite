# Microservice Architecture

## Overview

The backend consists of independent Node.js + TypeScript microservices, each owning its domain and database schema.

## Service Catalog

| Service              | Port | Database             | Responsibility                                  |
| -------------------- | ---- | -------------------- | ----------------------------------------------- |
| API Gateway          | 3000 | -                    | Routing, auth verification, rate limiting, CORS |
| Auth Service         | 3001 | college_auth         | Authentication, JWT, user management            |
| Student Service      | 3002 | college_student      | Student domain, enrollment, student data        |
| Teacher Service      | 3003 | college_teacher      | Teacher domain, assignments                     |
| Admin Service        | 3004 | college_admin        | Academic structures, courses, departments       |
| Notification Service | 3005 | college_notification | Notifications, announcements                    |
| File Service         | 3006 | college_file         | File uploads, storage, retrieval                |
| Audit Service        | 3007 | college_audit        | Audit logs, activity tracking                   |
| Exam Service         | 3008 | college_admin        | Exam management, schedules (shares admin DB)    |

## Service Architecture Pattern

Each service follows clean architecture:

```
src/
├── controllers/          # HTTP request handlers
│   ├── student.controller.ts
│   └── index.ts
├── services/            # Business logic
│   ├── student.service.ts
│   └── enrollment.service.ts
├── repositories/        # Data access layer
│   ├── student.repository.ts
│   └── enrollment.repository.ts
├── entities/           # Database entities (TypeORM)
│   ├── student.entity.ts
│   └── enrollment.entity.ts
├── dto/                # Data transfer objects
│   ├── create-student.dto.ts
│   ├── update-student.dto.ts
│   └── student-response.dto.ts
├── validators/         # Input validation schemas
│   └── student.validator.ts
├── middleware/         # Express middleware
│   ├── auth.middleware.ts
│   ├── validation.middleware.ts
│   └── error.middleware.ts
├── guards/            # Authorization guards
│   ├── role.guard.ts
│   └── permission.guard.ts
├── policies/          # Authorization policies
│   └── student.policy.ts
├── events/            # Domain events
│   ├── student-registered.event.ts
│   └── event-emitter.ts
├── utils/             # Utilities
│   ├── logger.ts
│   └── response.ts
├── config/            # Configuration
│   ├── database.config.ts
│   └── app.config.ts
├── routes/            # Route definitions
│   └── student.routes.ts
├── types/             # TypeScript types
│   └── express.d.ts
└── app.ts             # Express app setup
```

## Request Flow

```
HTTP Request
    ↓
API Gateway
    ↓
[Rate Limiting]
    ↓
[CORS Check]
    ↓
[JWT Verification]
    ↓
[Correlation ID]
    ↓
[Route to Service]
    ↓
Microservice
    ↓
Controller
    ↓
[Input Validation]
    ↓
[Authorization Check]
    ↓
Service (Business Logic)
    ↓
[Business Rules]
    ↓
Repository
    ↓
[Database Transaction]
    ↓
Database
    ↓
[Event Emission]
    ↓
Response
```

## API Gateway

**Technology:** Express.js + http-proxy-middleware

**Responsibilities:**

1. Route requests to appropriate microservices
2. Verify JWT tokens (but don't decode full user permissions)
3. Apply rate limiting
4. Generate correlation IDs
5. Apply CORS headers
6. Log requests
7. Normalize errors

**Route Mapping:**

```typescript
{
  '/api/v1/auth/*': 'http://auth-service:3001',
  '/api/v1/students/*': 'http://student-service:3002',
  '/api/v1/teachers/*': 'http://teacher-service:3003',
  '/api/v1/admin/*': 'http://admin-service:3004',
  '/api/v1/attendance/*': 'http://student-service:3002', // or separate service
  '/api/v1/courses/*': 'http://admin-service:3004',
  '/api/v1/subjects/*': 'http://admin-service:3004',
  '/api/v1/exams/*': 'http://exam-service:3008',
  '/api/v1/fees/*': 'http://student-service:3002',
  '/api/v1/notifications/*': 'http://notification-service:3005',
  '/api/v1/files/*': 'http://file-service:3006',
  '/api/v1/audit/*': 'http://audit-service:3007'
}
```

**Security Headers:**

```typescript
helmet({
  contentSecurityPolicy: true,
  crossOriginEmbedderPolicy: true,
  crossOriginOpenerPolicy: true,
  crossOriginResourcePolicy: true,
  dnsPrefetchControl: true,
  frameguard: true,
  hidePoweredBy: true,
  hsts: true,
  ieNoOpen: true,
  noSniff: true,
  originAgentCluster: true,
  permittedCrossDomainPolicies: true,
  referrerPolicy: true,
  xssFilter: true,
});
```

## Auth Service

**Endpoints:**

```
POST   /api/v1/auth/register/student
POST   /api/v1/auth/register/teacher
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout
POST   /api/v1/auth/forgot-password
POST   /api/v1/auth/reset-password
GET    /api/v1/auth/me
PUT    /api/v1/auth/change-password
```

**Database:** `college_auth`

**Tables:**

- users (id, email, password_hash, role, status, created_at, updated_at)
- roles (id, name, description)
- permissions (id, name, resource, action)
- user_roles (user_id, role_id)
- role_permissions (role_id, permission_id)
- refresh_tokens (id, user_id, token_hash, expires_at, revoked)
- password_reset_tokens (id, user_id, token_hash, expires_at, used)

**JWT Structure:**

```typescript
{
  sub: userId,           // Subject (user ID)
  email: string,
  role: 'STUDENT' | 'TEACHER' | 'ADMIN',
  status: 'PENDING' | 'APPROVED' | 'ACTIVE' | 'SUSPENDED',
  permissions: string[], // ['student:profile:read', ...]
  iat: number,          // Issued at
  exp: number           // Expires at (15 minutes)
}
```

**Refresh Token:**

- Stored in database as hash
- 7-day expiry
- Single-use (rotated on refresh)
- HttpOnly cookie

## Student Service

**Endpoints:**

```
GET    /api/v1/students/me/profile
PUT    /api/v1/students/me/profile
GET    /api/v1/students/me/attendance
GET    /api/v1/students/me/courses
GET    /api/v1/students/me/marks
GET    /api/v1/students/me/fees
GET    /api/v1/students/me/assignments
POST   /api/v1/students/me/assignments/:id/submit
GET    /api/v1/students/me/exams
GET    /api/v1/students/me/timetable
```

**Database:** `college_student`

**Tables:**

- students (id, user_id, first_name, last_name, dob, gender, email, phone, address, profile_picture, course_id, department_id, semester, admission_year, guardian_name, guardian_phone, guardian_email, status, created_at, updated_at)
- student_enrollments (id, student_id, course_id, academic_year, semester, enrollment_date)
- student_attendance (id, student_id, subject_id, class_id, date, status, marked_by, notes, created_at)
- student_fees (id, student_id, fee_structure_id, total_amount, paid_amount, due_date, status, created_at, updated_at)
- payments (id, student_fee_id, amount, payment_date, payment_method, transaction_id, receipt_url)

**Authorization:**

- Students can only access their own data
- `GET /api/v1/students/me/*` extracts student ID from JWT
- Attempts to access `/api/v1/students/:id` where `id !== tokenStudentId` → 403

## Teacher Service

**Endpoints:**

```
GET    /api/v1/teachers/me/profile
PUT    /api/v1/teachers/me/profile
GET    /api/v1/teachers/me/subjects
GET    /api/v1/teachers/me/classes
GET    /api/v1/teachers/me/students
GET    /api/v1/teachers/me/timetable
POST   /api/v1/teachers/attendance
PUT    /api/v1/teachers/attendance/:id
GET    /api/v1/teachers/attendance
POST   /api/v1/teachers/marks
PUT    /api/v1/teachers/marks/:id
GET    /api/v1/teachers/assignments
POST   /api/v1/teachers/assignments
PUT    /api/v1/teachers/assignments/:id
DELETE /api/v1/teachers/assignments/:id
GET    /api/v1/teachers/assignments/:id/submissions
```

**Database:** `college_teacher`

**Tables:**

- teachers (id, user_id, first_name, last_name, email, phone, dob, gender, address, qualification, specialization, experience, department_id, designation, joining_date, profile_picture, status, created_at, updated_at)
- teacher_assignments (id, teacher_id, subject_id, class_id, academic_year, semester, assigned_date)
- teacher_attendance (id, teacher_id, date, status, marked_at)
- assignments (id, teacher_id, subject_id, class_id, title, description, due_date, attachments, created_at, updated_at)
- assignment_submissions (id, assignment_id, student_id, submission_date, attachments, feedback, marks, graded_at)

**Authorization:**

- Teachers can only access assigned students/subjects/classes
- Before returning student list, verify teacher is assigned to that class
- Before marking attendance, verify teacher is assigned to that subject+class
- Policy: `canAccessStudent(teacherId, studentId)` → checks teacher_assignments

## Admin Service

**Endpoints:**

```
# Student Management
GET    /api/v1/admin/students
GET    /api/v1/admin/students/:id
POST   /api/v1/admin/students
PUT    /api/v1/admin/students/:id
PATCH  /api/v1/admin/students/:id/approve
PATCH  /api/v1/admin/students/:id/reject
PATCH  /api/v1/admin/students/:id/suspend
DELETE /api/v1/admin/students/:id

# Teacher Management
GET    /api/v1/admin/teachers
GET    /api/v1/admin/teachers/:id
POST   /api/v1/admin/teachers
PUT    /api/v1/admin/teachers/:id
PATCH  /api/v1/admin/teachers/:id/approve
PATCH  /api/v1/admin/teachers/:id/reject
PATCH  /api/v1/admin/teachers/:id/suspend
DELETE /api/v1/admin/teachers/:id

# Department Management
GET    /api/v1/admin/departments
POST   /api/v1/admin/departments
PUT    /api/v1/admin/departments/:id
DELETE /api/v1/admin/departments/:id

# Course Management
GET    /api/v1/admin/courses
POST   /api/v1/admin/courses
PUT    /api/v1/admin/courses/:id
DELETE /api/v1/admin/courses/:id

# Subject Management
GET    /api/v1/admin/subjects
POST   /api/v1/admin/subjects
PUT    /api/v1/admin/subjects/:id
DELETE /api/v1/admin/subjects/:id

# Class Management
GET    /api/v1/admin/classes
POST   /api/v1/admin/classes
PUT    /api/v1/admin/classes/:id
DELETE /api/v1/admin/classes/:id

# Timetable Management
GET    /api/v1/admin/timetables
POST   /api/v1/admin/timetables
PUT    /api/v1/admin/timetables/:id
DELETE /api/v1/admin/timetables/:id

# Announcements
GET    /api/v1/admin/announcements
POST   /api/v1/admin/announcements
PUT    /api/v1/admin/announcements/:id
DELETE /api/v1/admin/announcements/:id
```

**Database:** `college_admin`

**Tables:**

- departments (id, name, code, description, head_id, established_date, is_active, created_at, updated_at, deleted_at)
- courses (id, name, code, department_id, duration_years, total_semesters, total_credits, description, is_active, created_at, updated_at, deleted_at)
- subjects (id, name, code, course_id, semester, credits, description, is_elective, is_active, created_at, updated_at, deleted_at)
- classes (id, course_id, semester, section, academic_year, room_id, class_teacher_id, created_at, updated_at)
- timetables (id, class_id, subject_id, teacher_id, day_of_week, start_time, end_time, room_id, academic_year, semester, created_at, updated_at)
- rooms (id, room_number, building, capacity, room_type, is_available)
- fee_structures (id, course_id, semester, academic_year, tuition_fee, library_fee, lab_fee, exam_fee, other_fee, total_fee, created_at, updated_at)

**Authorization:**

- Admin endpoints require `ADMIN` role
- Certain destructive operations may require specific permissions
- Example: `admin:student:delete` permission for DELETE operations

## Notification Service

**Endpoints:**

```
GET    /api/v1/notifications/me
PATCH  /api/v1/notifications/:id/read
PATCH  /api/v1/notifications/mark-all-read
GET    /api/v1/notifications/unread-count
```

**Database:** `college_notification`

**Tables:**

- notifications (id, user_id, type, title, message, data, is_read, read_at, created_at)
- announcements (id, title, content, target_role, target_department_id, target_course_id, published_at, expires_at, created_by, created_at, updated_at)

**Event Handlers:**

- `StudentRegistered` → Send welcome notification
- `StudentApproved` → Send approval notification
- `AttendanceMarked` → Send low-attendance alert (if below threshold)
- `MarksPublished` → Send marks notification
- `AssignmentCreated` → Send assignment notification
- `FeePaymentDue` → Send fee reminder

## File Service

**Endpoints:**

```
POST   /api/v1/files/upload
GET    /api/v1/files/:id
DELETE /api/v1/files/:id
```

**Database:** `college_file`

**Tables:**

- files (id, user_id, filename, original_filename, mime_type, size, path, entity_type, entity_id, created_at)

**Storage:**

- Development: Local filesystem (`uploads/`)
- Production: Abstracted (S3/GCS-ready)

**Security:**

- Validate file types (whitelist: jpg, png, pdf, docx)
- Validate file sizes (profile: 5MB, assignment: 10MB)
- Generate secure filenames (UUID + extension)
- Virus scanning integration point
- Authorization: Users can only access their own files or public files

## Audit Service

**Endpoints:**

```
GET    /api/v1/audit/logs
GET    /api/v1/audit/logs/:id
```

**Database:** `college_audit`

**Tables:**

- audit_logs (id, user_id, user_role, action, entity_type, entity_id, old_value, new_value, ip_address, user_agent, correlation_id, created_at)

**Logged Actions:**

- LOGIN, LOGOUT
- REGISTRATION
- APPROVAL, REJECTION, SUSPENSION
- PROFILE_UPDATE
- ATTENDANCE_MARK, ATTENDANCE_UPDATE
- MARKS_CREATE, MARKS_UPDATE, MARKS_FINALIZE
- FEE_PAYMENT
- STUDENT_CREATE, STUDENT_UPDATE, STUDENT_DELETE
- TEACHER_CREATE, TEACHER_UPDATE, TEACHER_DELETE
- COURSE_CREATE, COURSE_UPDATE, COURSE_DELETE

**Middleware:**

```typescript
// Every service sends audit events
auditService.log({
  userId: req.user.id,
  userRole: req.user.role,
  action: 'STUDENT_UPDATE',
  entityType: 'STUDENT',
  entityId: studentId,
  oldValue: JSON.stringify(oldStudent),
  newValue: JSON.stringify(newStudent),
  ipAddress: req.ip,
  userAgent: req.get('user-agent'),
  correlationId: req.correlationId,
});
```

## Inter-Service Communication

### Synchronous (HTTP)

**Example:** Admin approves student → Admin Service calls Auth Service to update user status

```typescript
// admin-service
await authServiceClient.patch(`/internal/users/${userId}`, {
  status: 'APPROVED',
});
```

**Internal Routes:** `/internal/*` (not exposed via API Gateway)

### Asynchronous (Events)

**Example:** Student registered → Event emitted → Notification Service picks it up

```typescript
// student-service
eventEmitter.emit('student.registered', {
  studentId: student.id,
  email: student.email,
  name: `${student.firstName} ${student.lastName}`,
});

// notification-service
eventEmitter.on('student.registered', async (data) => {
  await notificationService.create({
    userId: data.studentId,
    type: 'REGISTRATION_SUCCESS',
    title: 'Registration Successful',
    message: 'Your registration is pending approval.',
  });
});
```

**Event Bus:** Lightweight in-process emitter initially; upgrade to RabbitMQ/Kafka later

## Database Transactions

Use transactions for multi-step operations:

```typescript
// Example: Student enrollment
const queryRunner = dataSource.createQueryRunner();
await queryRunner.connect();
await queryRunner.startTransaction();

try {
  const student = await queryRunner.manager.save(Student, studentData);
  const enrollment = await queryRunner.manager.save(Enrollment, {
    studentId: student.id,
    courseId: studentData.courseId,
    academicYear: new Date().getFullYear(),
  });

  await queryRunner.commitTransaction();
  return student;
} catch (err) {
  await queryRunner.rollbackTransaction();
  throw err;
} finally {
  await queryRunner.release();
}
```

## Error Handling

**Custom Errors:**

```typescript
class ValidationError extends Error {}
class AuthenticationError extends Error {}
class AuthorizationError extends Error {}
class NotFoundError extends Error {}
class ConflictError extends Error {}
class BusinessRuleError extends Error {}
```

**Global Error Handler:**

```typescript
app.use((err, req, res, next) => {
  logger.error({
    error: err.message,
    stack: err.stack,
    correlationId: req.correlationId,
  });

  if (err instanceof ValidationError) {
    return res.status(400).json({
      success: false,
      error: { code: 'VALIDATION_ERROR', message: err.message },
    });
  }

  if (err instanceof AuthorizationError) {
    return res.status(403).json({
      success: false,
      error: { code: 'FORBIDDEN', message: err.message },
    });
  }

  res.status(500).json({
    success: false,
    error: { code: 'INTERNAL_ERROR', message: 'An error occurred' },
  });
});
```

## Health Checks

Each service exposes:

```
GET /health         # Overall health
GET /health/live    # Liveness probe
GET /health/ready   # Readiness probe
```

**Response:**

```json
{
  "status": "healthy",
  "timestamp": "2026-09-03T07:17:11.696Z",
  "uptime": 3600,
  "database": "connected",
  "version": "1.0.0"
}
```

## Configuration

Each service uses environment variables:

```env
NODE_ENV=development
PORT=3002
DB_HOST=localhost
DB_PORT=3306
DB_USERNAME=root
DB_PASSWORD=root
DB_NAME=college_student
JWT_ACCESS_SECRET=xxx
JWT_REFRESH_SECRET=xxx
CORS_ORIGIN=http://localhost:4200
API_GATEWAY_URL=http://localhost:3000
LOG_LEVEL=info
```

## Technology Stack Per Service

- **Framework:** Express.js
- **Language:** TypeScript (strict mode)
- **ORM:** TypeORM
- **Validation:** Joi / Zod
- **Logging:** Winston
- **HTTP Client:** Axios
- **Password Hashing:** Argon2
- **JWT:** jsonwebtoken
- **Testing:** Jest + Supertest
