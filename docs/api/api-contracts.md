# API Contracts

## Base URL

```
Development: http://localhost:3000
Production: https://api.college.edu
```

## API Versioning

All APIs are versioned:

```
/api/v1/*
```

## Common Headers

### Request Headers

```
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
X-Correlation-ID: <uuid> (optional, generated if not provided)
```

### Response Headers

```
Content-Type: application/json
X-Correlation-ID: <uuid>
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1725349919
```

## Standard Response Format

### Success Response

```json
{
  "success": true,
  "data": {
    // Response data
  },
  "message": "Operation successful"
}
```

### Paginated Response

```json
{
  "success": true,
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5,
    "hasNext": true,
    "hasPrev": false
  }
}
```

### Error Response

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {} // Optional, for validation errors
  }
}
```

## HTTP Status Codes

| Code | Meaning               | Usage                               |
| ---- | --------------------- | ----------------------------------- |
| 200  | OK                    | Successful GET, PUT, PATCH          |
| 201  | Created               | Successful POST                     |
| 204  | No Content            | Successful DELETE                   |
| 400  | Bad Request           | Validation error, malformed request |
| 401  | Unauthorized          | Missing or invalid authentication   |
| 403  | Forbidden             | Insufficient permissions            |
| 404  | Not Found             | Resource doesn't exist              |
| 409  | Conflict              | Resource conflict (duplicate email) |
| 422  | Unprocessable Entity  | Business rule violation             |
| 429  | Too Many Requests     | Rate limit exceeded                 |
| 500  | Internal Server Error | Server error                        |
| 503  | Service Unavailable   | Service temporarily down            |

## Error Codes

```typescript
enum ErrorCode {
  // Authentication
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  ACCOUNT_LOCKED = 'ACCOUNT_LOCKED',
  ACCOUNT_PENDING = 'ACCOUNT_PENDING',
  ACCOUNT_REJECTED = 'ACCOUNT_REJECTED',
  ACCOUNT_SUSPENDED = 'ACCOUNT_SUSPENDED',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  TOKEN_INVALID = 'TOKEN_INVALID',

  // Authorization
  FORBIDDEN = 'FORBIDDEN',
  INSUFFICIENT_PERMISSIONS = 'INSUFFICIENT_PERMISSIONS',
  RESOURCE_NOT_OWNED = 'RESOURCE_NOT_OWNED',

  // Validation
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  INVALID_EMAIL = 'INVALID_EMAIL',
  INVALID_PHONE = 'INVALID_PHONE',
  WEAK_PASSWORD = 'WEAK_PASSWORD',

  // Business Rules
  DUPLICATE_EMAIL = 'DUPLICATE_EMAIL',
  STUDENT_NOT_ENROLLED = 'STUDENT_NOT_ENROLLED',
  TEACHER_NOT_ASSIGNED = 'TEACHER_NOT_ASSIGNED',
  MARKS_ALREADY_FINALIZED = 'MARKS_ALREADY_FINALIZED',
  ATTENDANCE_ALREADY_MARKED = 'ATTENDANCE_ALREADY_MARKED',

  // Resources
  NOT_FOUND = 'NOT_FOUND',
  STUDENT_NOT_FOUND = 'STUDENT_NOT_FOUND',
  TEACHER_NOT_FOUND = 'TEACHER_NOT_FOUND',
  COURSE_NOT_FOUND = 'COURSE_NOT_FOUND',

  // System
  INTERNAL_ERROR = 'INTERNAL_ERROR',
  DATABASE_ERROR = 'DATABASE_ERROR',
  SERVICE_UNAVAILABLE = 'SERVICE_UNAVAILABLE',
}
```

---

# Authentication Endpoints

## POST /api/v1/auth/register/student

Register a new student.

**Request:**

```json
{
  "firstName": "John",
  "lastName": "Doe",
  "dateOfBirth": "2005-05-15",
  "gender": "MALE",
  "email": "john.doe@example.com",
  "phone": "+1234567890",
  "alternatePhone": "+1234567891",
  "addressLine1": "123 Main St",
  "addressLine2": "Apt 4B",
  "city": "Springfield",
  "state": "Illinois",
  "country": "USA",
  "postalCode": "62701",
  "guardianName": "Jane Doe",
  "guardianPhone": "+1234567892",
  "guardianEmail": "jane.doe@example.com",
  "previousQualification": "High School",
  "courseId": 1,
  "departmentId": 1,
  "admissionYear": 2026,
  "password": "SecurePass@123",
  "confirmPassword": "SecurePass@123"
}
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "message": "Registration successful. Your account is pending approval.",
    "studentId": "STU2026001"
  }
}
```

---

## POST /api/v1/auth/register/teacher

Register a new teacher.

**Request:**

```json
{
  "firstName": "Sarah",
  "lastName": "Johnson",
  "email": "sarah.johnson@college.edu",
  "phone": "+1234567890",
  "dateOfBirth": "1985-03-20",
  "gender": "FEMALE",
  "addressLine1": "456 Oak Ave",
  "city": "Springfield",
  "state": "Illinois",
  "country": "USA",
  "postalCode": "62702",
  "qualification": "PhD in Computer Science",
  "specialization": "Machine Learning",
  "experienceYears": 10,
  "departmentId": 1,
  "designation": "Associate Professor",
  "joiningDate": "2026-09-01",
  "password": "SecurePass@123",
  "confirmPassword": "SecurePass@123"
}
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "message": "Registration successful. Your account is pending approval.",
    "teacherId": "TCH2026001"
  }
}
```

---

## POST /api/v1/auth/login

Authenticate user and receive tokens.

**Request:**

```json
{
  "email": "john.doe@example.com",
  "password": "SecurePass@123",
  "rememberMe": false
}
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 123,
      "email": "john.doe@example.com",
      "role": "STUDENT",
      "status": "APPROVED",
      "firstName": "John",
      "lastName": "Doe",
      "profilePicture": "/uploads/profiles/uuid.jpg"
    }
  }
}
```

**Error Response:** `401 Unauthorized`

```json
{
  "success": false,
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Invalid email or password"
  }
}
```

**Error Response:** `403 Forbidden` (Pending Approval)

```json
{
  "success": false,
  "error": {
    "code": "ACCOUNT_PENDING",
    "message": "Your account is pending approval"
  }
}
```

---

## POST /api/v1/auth/refresh

Refresh access token using refresh token.

**Request:**

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

---

## POST /api/v1/auth/logout

Logout and revoke refresh token.

**Request:**

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "message": "Logged out successfully"
  }
}
```

---

## GET /api/v1/auth/me

Get current authenticated user.

**Headers:**

```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "id": 123,
    "email": "john.doe@example.com",
    "role": "STUDENT",
    "status": "APPROVED",
    "firstName": "John",
    "lastName": "Doe",
    "profilePicture": "/uploads/profiles/uuid.jpg",
    "permissions": [
      "student:profile:read",
      "student:profile:update",
      "student:attendance:read"
    ]
  }
}
```

---

## PUT /api/v1/auth/change-password

Change user password.

**Request:**

```json
{
  "currentPassword": "OldPass@123",
  "newPassword": "NewPass@123",
  "confirmPassword": "NewPass@123"
}
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "message": "Password changed successfully"
  }
}
```

---

# Student Endpoints

## GET /api/v1/students/me/profile

Get student's own profile.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "id": 123,
    "studentIdNumber": "STU2026001",
    "firstName": "John",
    "lastName": "Doe",
    "dateOfBirth": "2005-05-15",
    "gender": "MALE",
    "email": "john.doe@example.com",
    "phone": "+1234567890",
    "alternatePhone": "+1234567891",
    "address": {
      "line1": "123 Main St",
      "line2": "Apt 4B",
      "city": "Springfield",
      "state": "Illinois",
      "country": "USA",
      "postalCode": "62701"
    },
    "guardian": {
      "name": "Jane Doe",
      "phone": "+1234567892",
      "email": "jane.doe@example.com"
    },
    "academic": {
      "departmentId": 1,
      "departmentName": "Computer Science",
      "courseId": 1,
      "courseName": "B.Tech Computer Science",
      "admissionYear": 2026,
      "currentSemester": 1
    },
    "profilePicture": "/uploads/profiles/uuid.jpg",
    "status": "APPROVED"
  }
}
```

---

## PUT /api/v1/students/me/profile

Update student's own profile (limited fields).

**Request:**

```json
{
  "phone": "+1234567890",
  "alternatePhone": "+1234567891",
  "addressLine1": "123 New St",
  "addressLine2": "Apt 5C",
  "city": "Springfield",
  "state": "Illinois",
  "postalCode": "62701",
  "guardianPhone": "+1234567892",
  "guardianEmail": "jane.doe@example.com"
}
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "message": "Profile updated successfully"
  }
}
```

---

## GET /api/v1/students/me/attendance

Get student's attendance records.

**Query Parameters:**

```
?subjectId=5 (optional)
&month=9 (optional, 1-12)
&year=2026 (optional)
&page=1
&limit=20
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "summary": {
      "totalClasses": 100,
      "present": 85,
      "absent": 10,
      "late": 3,
      "excused": 2,
      "attendancePercentage": 85.0
    },
    "records": [
      {
        "id": 1,
        "date": "2026-09-02",
        "subjectName": "Data Structures",
        "subjectCode": "CS201",
        "status": "PRESENT",
        "markedBy": "Dr. Sarah Johnson"
      },
      {
        "id": 2,
        "date": "2026-09-02",
        "subjectName": "Database Systems",
        "subjectCode": "CS202",
        "status": "ABSENT",
        "markedBy": "Prof. Michael Brown"
      }
    ]
  },
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

---

## GET /api/v1/students/me/marks

Get student's marks.

**Query Parameters:**

```
?semester=1 (optional)
&subjectId=5 (optional)
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "summary": {
      "semester": 1,
      "sgpa": 8.5,
      "cgpa": 8.5,
      "totalCredits": 20,
      "earnedCredits": 20
    },
    "subjects": [
      {
        "subjectId": 5,
        "subjectName": "Data Structures",
        "subjectCode": "CS201",
        "credits": 4,
        "internal": {
          "obtained": 18,
          "max": 20
        },
        "midTerm": {
          "obtained": 25,
          "max": 30
        },
        "endTerm": {
          "obtained": 45,
          "max": 50
        },
        "total": {
          "obtained": 88,
          "max": 100
        },
        "grade": "A",
        "gradePoint": 9.0,
        "status": "PASS"
      }
    ]
  }
}
```

---

## GET /api/v1/students/me/fees

Get student's fee records.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "summary": {
      "totalFee": 50000,
      "paidAmount": 30000,
      "pendingAmount": 20000,
      "overdueAmount": 5000
    },
    "fees": [
      {
        "id": 1,
        "academicYear": 2026,
        "semester": 1,
        "totalAmount": 25000,
        "paidAmount": 15000,
        "discountAmount": 0,
        "fineAmount": 500,
        "pendingAmount": 10500,
        "dueDate": "2026-10-15",
        "status": "PARTIAL",
        "scholarshipApplied": false
      }
    ],
    "payments": [
      {
        "id": 1,
        "amount": 15000,
        "paymentDate": "2026-08-20T10:30:00Z",
        "paymentMethod": "UPI",
        "transactionId": "TXN123456789",
        "receiptNumber": "RCP2026001",
        "receiptUrl": "/uploads/receipts/uuid.pdf"
      }
    ]
  }
}
```

---

## GET /api/v1/students/me/courses

Get student's enrolled courses.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "course": {
      "id": 1,
      "name": "B.Tech Computer Science",
      "code": "BTCS",
      "department": "Computer Science",
      "durationYears": 4,
      "currentSemester": 1
    },
    "subjects": [
      {
        "id": 5,
        "name": "Data Structures",
        "code": "CS201",
        "credits": 4,
        "teacher": {
          "id": 10,
          "name": "Dr. Sarah Johnson",
          "email": "sarah.johnson@college.edu"
        }
      }
    ]
  }
}
```

---

## GET /api/v1/students/me/assignments

Get student's assignments.

**Query Parameters:**

```
?status=PENDING (optional: PENDING, SUBMITTED, GRADED, LATE)
&subjectId=5 (optional)
&page=1
&limit=20
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "title": "Binary Search Tree Implementation",
      "description": "Implement BST with insert, delete, and search operations",
      "subjectName": "Data Structures",
      "subjectCode": "CS201",
      "dueDate": "2026-09-10T23:59:59Z",
      "maxMarks": 10,
      "attachments": [
        {
          "name": "assignment.pdf",
          "url": "/uploads/assignments/uuid.pdf"
        }
      ],
      "submission": {
        "id": 10,
        "submittedAt": "2026-09-09T18:30:00Z",
        "attachments": [
          {
            "name": "solution.zip",
            "url": "/uploads/submissions/uuid.zip"
          }
        ],
        "remarks": "Completed all requirements",
        "feedback": "Good implementation. Consider edge cases.",
        "marksObtained": 9,
        "gradedAt": "2026-09-11T14:00:00Z",
        "status": "GRADED"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 15,
    "totalPages": 1
  }
}
```

---

## POST /api/v1/students/me/assignments/:id/submit

Submit assignment.

**Request:** `multipart/form-data`

```
files: File[] (multiple files)
remarks: string (optional)
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "submissionId": 10,
    "message": "Assignment submitted successfully"
  }
}
```

---

## GET /api/v1/students/me/exams

Get student's examination schedule.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "examName": "Mid-Term Examination",
      "examType": "MID_TERM",
      "subjectName": "Data Structures",
      "subjectCode": "CS201",
      "date": "2026-10-15",
      "startTime": "10:00:00",
      "endTime": "13:00:00",
      "duration": 180,
      "room": "Room 101, Building A",
      "maxMarks": 30
    }
  ]
}
```

---

## GET /api/v1/students/me/timetable

Get student's class timetable.

**Query Parameters:**

```
?day=MONDAY (optional)
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "MONDAY": [
      {
        "subjectName": "Data Structures",
        "subjectCode": "CS201",
        "teacherName": "Dr. Sarah Johnson",
        "startTime": "09:00:00",
        "endTime": "10:00:00",
        "room": "Room 201, Building A"
      },
      {
        "subjectName": "Database Systems",
        "subjectCode": "CS202",
        "teacherName": "Prof. Michael Brown",
        "startTime": "10:00:00",
        "endTime": "11:00:00",
        "room": "Room 202, Building A"
      }
    ],
    "TUESDAY": [...]
  }
}
```

---

# Teacher Endpoints

## GET /api/v1/teachers/me/profile

Get teacher's own profile.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "id": 10,
    "teacherIdNumber": "TCH2026001",
    "firstName": "Sarah",
    "lastName": "Johnson",
    "email": "sarah.johnson@college.edu",
    "phone": "+1234567890",
    "dateOfBirth": "1985-03-20",
    "gender": "FEMALE",
    "address": {
      "line1": "456 Oak Ave",
      "city": "Springfield",
      "state": "Illinois",
      "country": "USA",
      "postalCode": "62702"
    },
    "qualification": "PhD in Computer Science",
    "specialization": "Machine Learning",
    "experienceYears": 10,
    "department": {
      "id": 1,
      "name": "Computer Science"
    },
    "designation": "Associate Professor",
    "joiningDate": "2026-09-01",
    "profilePicture": "/uploads/profiles/uuid.jpg",
    "status": "APPROVED"
  }
}
```

---

## GET /api/v1/teachers/me/subjects

Get teacher's assigned subjects.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 5,
      "name": "Data Structures",
      "code": "CS201",
      "credits": 4,
      "semester": 1,
      "course": {
        "id": 1,
        "name": "B.Tech Computer Science"
      },
      "classes": [
        {
          "id": 1,
          "section": "A",
          "studentCount": 60
        }
      ]
    }
  ]
}
```

---

## GET /api/v1/teachers/me/students

Get students assigned to teacher.

**Query Parameters:**

```
?classId=1 (optional)
&subjectId=5 (optional)
&search=john (optional)
&page=1
&limit=20
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 123,
      "studentIdNumber": "STU2026001",
      "firstName": "John",
      "lastName": "Doe",
      "email": "john.doe@example.com",
      "phone": "+1234567890",
      "course": "B.Tech Computer Science",
      "semester": 1,
      "section": "A",
      "attendancePercentage": 85.0,
      "profilePicture": "/uploads/profiles/uuid.jpg"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 60,
    "totalPages": 3
  }
}
```

---

## POST /api/v1/teachers/attendance

Mark attendance for a class.

**Request:**

```json
{
  "classId": 1,
  "subjectId": 5,
  "date": "2026-09-03",
  "attendance": [
    {
      "studentId": 123,
      "status": "PRESENT"
    },
    {
      "studentId": 124,
      "status": "ABSENT"
    },
    {
      "studentId": 125,
      "status": "LATE",
      "notes": "Arrived 10 minutes late"
    }
  ]
}
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "message": "Attendance marked for 60 students",
    "markedCount": 60,
    "present": 55,
    "absent": 3,
    "late": 2
  }
}
```

---

## POST /api/v1/teachers/marks

Add or update marks.

**Request:**

```json
{
  "examinationScheduleId": 1,
  "marks": [
    {
      "studentId": 123,
      "marksObtained": 25,
      "remarks": "Excellent performance"
    },
    {
      "studentId": 124,
      "marksObtained": 18
    }
  ]
}
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "message": "Marks added for 2 students"
  }
}
```

---

## GET /api/v1/teachers/assignments

Get teacher's assignments.

**Query Parameters:**

```
?classId=1 (optional)
&subjectId=5 (optional)
&page=1
&limit=20
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "title": "Binary Search Tree Implementation",
      "description": "Implement BST with insert, delete, and search operations",
      "subject": {
        "id": 5,
        "name": "Data Structures",
        "code": "CS201"
      },
      "class": {
        "id": 1,
        "section": "A"
      },
      "dueDate": "2026-09-10T23:59:59Z",
      "maxMarks": 10,
      "isPublished": true,
      "submissionCount": 45,
      "totalStudents": 60,
      "createdAt": "2026-09-01T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 10,
    "totalPages": 1
  }
}
```

---

## POST /api/v1/teachers/assignments

Create new assignment.

**Request:** `multipart/form-data`

```
title: string
description: string
subjectId: number
classId: number
dueDate: string (ISO 8601)
maxMarks: number
files: File[] (optional)
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "id": 1,
    "message": "Assignment created successfully"
  }
}
```

---

## GET /api/v1/teachers/assignments/:id/submissions

Get submissions for an assignment.

**Query Parameters:**

```
?status=SUBMITTED (optional: SUBMITTED, GRADED, LATE)
&page=1
&limit=20
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 10,
      "student": {
        "id": 123,
        "studentIdNumber": "STU2026001",
        "name": "John Doe"
      },
      "submittedAt": "2026-09-09T18:30:00Z",
      "attachments": [
        {
          "name": "solution.zip",
          "url": "/uploads/submissions/uuid.zip"
        }
      ],
      "remarks": "Completed all requirements",
      "feedback": null,
      "marksObtained": null,
      "status": "SUBMITTED"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "totalPages": 3
  }
}
```

---

## PATCH /api/v1/teachers/assignments/:assignmentId/submissions/:submissionId/grade

Grade a submission.

**Request:**

```json
{
  "marksObtained": 9,
  "feedback": "Good implementation. Consider edge cases."
}
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "message": "Submission graded successfully"
  }
}
```

---

# Admin Endpoints

## GET /api/v1/admin/students

Get all students (admin).

**Query Parameters:**

```
?status=PENDING (optional)
&departmentId=1 (optional)
&courseId=1 (optional)
&semester=1 (optional)
&search=john (optional)
&page=1
&limit=20
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 123,
      "studentIdNumber": "STU2026001",
      "firstName": "John",
      "lastName": "Doe",
      "email": "john.doe@example.com",
      "phone": "+1234567890",
      "department": "Computer Science",
      "course": "B.Tech Computer Science",
      "semester": 1,
      "admissionYear": 2026,
      "status": "APPROVED",
      "createdAt": "2026-08-15T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 500,
    "totalPages": 25
  }
}
```

---

## PATCH /api/v1/admin/students/:id/approve

Approve student registration.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "message": "Student approved successfully"
  }
}
```

---

## PATCH /api/v1/admin/students/:id/reject

Reject student registration.

**Request:**

```json
{
  "reason": "Incomplete documents"
}
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "message": "Student registration rejected"
  }
}
```

---

## POST /api/v1/admin/departments

Create department.

**Request:**

```json
{
  "name": "Computer Science",
  "code": "CS",
  "description": "Department of Computer Science and Engineering",
  "establishedDate": "2000-01-01"
}
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "id": 1,
    "message": "Department created successfully"
  }
}
```

---

## POST /api/v1/admin/courses

Create course.

**Request:**

```json
{
  "name": "B.Tech Computer Science",
  "code": "BTCS",
  "departmentId": 1,
  "durationYears": 4,
  "totalSemesters": 8,
  "totalCredits": 160,
  "description": "Bachelor of Technology in Computer Science"
}
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "id": 1,
    "message": "Course created successfully"
  }
}
```

---

## GET /api/v1/admin/audit/logs

Get audit logs (admin only).

**Query Parameters:**

```
?userId=123 (optional)
&action=STUDENT_UPDATE (optional)
&entityType=STUDENT (optional)
&startDate=2026-09-01 (optional)
&endDate=2026-09-03 (optional)
&page=1
&limit=50
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "user": {
        "id": 10,
        "name": "Admin User",
        "role": "ADMIN"
      },
      "action": "STUDENT_APPROVE",
      "entityType": "STUDENT",
      "entityId": 123,
      "oldValue": { "status": "PENDING" },
      "newValue": { "status": "APPROVED" },
      "ipAddress": "192.168.1.100",
      "createdAt": "2026-09-03T07:15:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 1000,
    "totalPages": 20
  }
}
```

---

# File Upload Endpoint

## POST /api/v1/files/upload

Upload file.

**Request:** `multipart/form-data`

```
file: File
entityType: string (optional: "PROFILE", "ASSIGNMENT", "SUBMISSION")
entityId: number (optional)
```

**Response:** `201 Created`

```json
{
  "success": true,
  "data": {
    "id": 100,
    "filename": "uuid.jpg",
    "originalFilename": "profile.jpg",
    "mimeType": "image/jpeg",
    "size": 102400,
    "url": "/uploads/profiles/uuid.jpg"
  }
}
```

---

# Notification Endpoints

## GET /api/v1/notifications/me

Get user notifications.

**Query Parameters:**

```
?isRead=false (optional)
&page=1
&limit=20
```

**Response:** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "type": "ASSIGNMENT_CREATED",
      "title": "New Assignment",
      "message": "Binary Search Tree Implementation assignment has been posted",
      "isRead": false,
      "createdAt": "2026-09-01T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 50,
    "totalPages": 3
  }
}
```

---

## PATCH /api/v1/notifications/:id/read

Mark notification as read.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "message": "Notification marked as read"
  }
}
```

---

## GET /api/v1/notifications/unread-count

Get unread notification count.

**Response:** `200 OK`

```json
{
  "success": true,
  "data": {
    "count": 5
  }
}
```

---

# Pagination & Filtering

All list endpoints support:

**Pagination:**

```
?page=1 (default: 1)
&limit=20 (default: 20, max: 100)
```

**Sorting:**

```
?sortBy=createdAt (field name)
&sortOrder=DESC (ASC or DESC, default: DESC)
```

**Search:**

```
?search=john (searches across relevant fields)
```

---

# Rate Limiting

API Gateway enforces rate limits:

| Role            | Requests | Window     |
| --------------- | -------- | ---------- |
| Unauthenticated | 20       | 15 minutes |
| Student         | 100      | 15 minutes |
| Teacher         | 200      | 15 minutes |
| Admin           | 500      | 15 minutes |

**Rate Limit Headers:**

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1725349919 (Unix timestamp)
```

**Rate Limit Exceeded:** `429 Too Many Requests`

```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests. Please try again later.",
    "retryAfter": 300
  }
}
```
