# Authentication & Authorization Flow

## Overview

The College Management System uses **JWT-based authentication** with refresh token rotation and **role-based + permission-based authorization**.

## Authentication Architecture

```
┌─────────────────┐
│   Client (MFE)  │
└────────┬────────┘
         │
         │ 1. Login (email, password)
         ▼
┌─────────────────────────────────────┐
│         API Gateway                 │
│       Port 3000                     │
└────────┬────────────────────────────┘
         │
         │ 2. Forward to Auth Service
         ▼
┌─────────────────────────────────────┐
│       Auth Service                  │
│       Port 3001                     │
│                                     │
│  ┌──────────────────────────┐      │
│  │ 1. Validate credentials  │      │
│  │ 2. Check account status  │      │
│  │ 3. Generate JWT tokens   │      │
│  │ 4. Store refresh token   │      │
│  └──────────────────────────┘      │
└────────┬────────────────────────────┘
         │
         │ 3. Return tokens
         ▼
┌─────────────────────────────────────┐
│         Client                      │
│                                     │
│  Store:                            │
│  - Access Token (memory/state)     │
│  - Refresh Token (HttpOnly cookie) │
└─────────────────────────────────────┘
```

## Registration Flow

### Student Registration

```
Student
   ↓
Fill Registration Form
   ↓
POST /api/v1/auth/register/student
   ↓
API Gateway
   ↓
Auth Service
   ↓
┌────────────────────────────────────┐
│ 1. Validate input                  │
│ 2. Check duplicate email           │
│ 3. Hash password (Argon2)          │
│ 4. Create user (status: PENDING)   │
│ 5. Create student record           │
│ 6. Emit StudentRegistered event    │
└────────────────────────────────────┘
   ↓
Return success (no auto-login)
   ↓
Notification: "Registration pending approval"
   ↓
Admin Reviews
   ↓
Admin Approves/Rejects
   ↓
User status updated
   ↓
Notification: "Registration approved" or "Registration rejected"
   ↓
If approved: Student can now login
```

**Key Points:**

- Registration does NOT automatically log in the user
- User status remains `PENDING` until admin approval
- Pending users cannot access protected routes
- Approval workflow prevents unauthorized access

### Teacher Registration

Similar flow to student registration:

```
POST /api/v1/auth/register/teacher
   ↓
Create user (status: PENDING)
   ↓
Create teacher record
   ↓
Emit TeacherRegistered event
   ↓
Admin approval required
```

## Login Flow

```
User
   ↓
Enter email & password
   ↓
POST /api/v1/auth/login
   ↓
API Gateway
   ↓
Auth Service
   ↓
┌────────────────────────────────────┐
│ 1. Find user by email              │
│ 2. Check account not locked        │
│ 3. Verify password hash            │
│ 4. Check account status            │
│ 5. Generate access token (15 min)  │
│ 6. Generate refresh token (7 days) │
│ 7. Store refresh token in DB       │
│ 8. Update last_login_at            │
│ 9. Reset failed_login_attempts     │
│ 10. Emit LoginSuccess event        │
└────────────────────────────────────┘
   ↓
Return:
   ↓
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGc...",
    "refreshToken": "eyJhbGc..." (also in HttpOnly cookie),
    "user": {
      "id": 123,
      "email": "student@example.com",
      "role": "STUDENT",
      "status": "APPROVED",
      "permissions": [...]
    }
  }
}
   ↓
Client stores accessToken in memory/state
   ↓
Client uses accessToken in Authorization header
```

### Failed Login Handling

```
Login fails
   ↓
Increment failed_login_attempts
   ↓
If failed_login_attempts >= 5:
   ↓
Set locked_until = NOW() + 15 minutes
   ↓
Return 429 Too Many Requests
```

## JWT Structure

### Access Token (Short-lived: 15 minutes)

```json
{
  "sub": "123",
  "email": "student@example.com",
  "role": "STUDENT",
  "status": "APPROVED",
  "permissions": [
    "student:profile:read",
    "student:profile:update",
    "student:attendance:read",
    "student:marks:read",
    "student:fees:read"
  ],
  "iat": 1725349219,
  "exp": 1725350119
}
```

### Refresh Token (Long-lived: 7 days)

```json
{
  "sub": "123",
  "tokenId": "uuid-v4",
  "type": "refresh",
  "iat": 1725349219,
  "exp": 1725954019
}
```

**Security:**

- Access token is stateless (JWT verification only)
- Refresh token is stored in database (can be revoked)
- Refresh token is hashed before storage (SHA-256)
- Refresh token rotates on every refresh

## Token Refresh Flow

```
Access Token expires
   ↓
Client detects 401 Unauthorized
   ↓
POST /api/v1/auth/refresh
   ↓
Send refresh token
   ↓
Auth Service
   ↓
┌────────────────────────────────────┐
│ 1. Verify refresh token signature  │
│ 2. Check token not expired         │
│ 3. Hash token and lookup in DB     │
│ 4. Check token not revoked         │
│ 5. Check user still active         │
│ 6. Generate new access token       │
│ 7. Generate new refresh token      │
│ 8. Revoke old refresh token        │
│ 9. Store new refresh token         │
└────────────────────────────────────┘
   ↓
Return new tokens
   ↓
Client updates tokens
   ↓
Retry original request
```

**Token Rotation:**

- Old refresh token is immediately revoked
- New refresh token is issued
- Prevents token reuse attacks

## Logout Flow

```
User clicks logout
   ↓
POST /api/v1/auth/logout
   ↓
Send refresh token
   ↓
Auth Service
   ↓
┌────────────────────────────────────┐
│ 1. Revoke refresh token in DB      │
│ 2. Emit LogoutSuccess event        │
└────────────────────────────────────┘
   ↓
Return success
   ↓
Client clears tokens
   ↓
Redirect to /login
```

**Note:** Access tokens cannot be revoked (stateless), but they expire in 15 minutes.

## Authorization Flow

### API Gateway Layer

```
Request arrives
   ↓
┌────────────────────────────────────┐
│ 1. Extract Authorization header    │
│ 2. Verify JWT signature            │
│ 3. Check token not expired         │
│ 4. Attach user context to request  │
└────────────────────────────────────┘
   ↓
If invalid: 401 Unauthorized
   ↓
If valid: Forward to microservice
```

**Gateway does NOT check:**

- Fine-grained permissions
- Resource ownership
- Business rules

**Gateway attaches to request:**

```typescript
req.user = {
  id: 123,
  email: "student@example.com",
  role: "STUDENT",
  status: "APPROVED",
  permissions: [...]
}
```

### Microservice Layer

Each microservice performs its own authorization:

```
Request arrives at service
   ↓
Controller receives req.user (from gateway)
   ↓
┌────────────────────────────────────┐
│ Authorization Checks:              │
│                                    │
│ 1. Role Check                      │
│    if (!req.user.role === 'STUDENT') │
│       throw ForbiddenError         │
│                                    │
│ 2. Status Check                    │
│    if (req.user.status !== 'APPROVED') │
│       throw ForbiddenError         │
│                                    │
│ 3. Permission Check                │
│    if (!hasPermission('student:profile:read')) │
│       throw ForbiddenError         │
│                                    │
│ 4. Resource Ownership Check        │
│    if (requestedId !== req.user.id) │
│       throw ForbiddenError         │
│                                    │
│ 5. Resource Relationship Check     │
│    if (!canAccessResource(...))   │
│       throw ForbiddenError         │
└────────────────────────────────────┘
   ↓
If all checks pass: Execute business logic
```

## Authorization Patterns

### Pattern 1: Self-Access Only (Students)

```typescript
// Student can only access their own profile
@Get('/api/v1/students/me/profile')
async getProfile(@User() user: AuthUser) {
  // URL uses 'me', backend resolves to actual student ID
  const student = await this.studentService.findByUserId(user.id);

  if (!student) {
    throw new NotFoundException('Student not found');
  }

  return student;
}
```

**Security:**

- Student ID comes from JWT, not request parameter
- Student cannot manipulate URL to access other students
- No `/api/v1/students/:id` endpoint exposed to students

### Pattern 2: Relationship-Based Access (Teachers)

```typescript
// Teacher can only access assigned students
@Get('/api/v1/teachers/students/:studentId')
async getStudent(
  @User() user: AuthUser,
  @Param('studentId') studentId: number
) {
  const teacher = await this.teacherService.findByUserId(user.id);

  // Check if teacher is assigned to this student's class
  const canAccess = await this.authorizationService.canTeacherAccessStudent(
    teacher.id,
    studentId
  );

  if (!canAccess) {
    throw new ForbiddenError('You are not assigned to this student');
  }

  return this.studentService.findById(studentId);
}
```

**Authorization Service checks:**

```typescript
async canTeacherAccessStudent(teacherId: number, studentId: number): Promise<boolean> {
  // Get student's enrollments
  const enrollment = await this.enrollmentRepo.findOne({
    where: { studentId },
    relations: ['class']
  });

  if (!enrollment) return false;

  // Check if teacher is assigned to this class
  const assignment = await this.teacherAssignmentRepo.findOne({
    where: {
      teacherId,
      classId: enrollment.class.id,
      isActive: true
    }
  });

  return !!assignment;
}
```

### Pattern 3: Admin Full Access with Audit

```typescript
// Admin can access any student, but action is logged
@Get('/api/v1/admin/students/:id')
async getStudent(
  @User() user: AuthUser,
  @Param('id') studentId: number,
  @Req() req: Request
) {
  if (user.role !== 'ADMIN') {
    throw new ForbiddenError('Admin access required');
  }

  const student = await this.studentService.findById(studentId);

  // Log admin access
  await this.auditService.log({
    userId: user.id,
    userRole: user.role,
    action: 'STUDENT_VIEW',
    entityType: 'STUDENT',
    entityId: studentId,
    ipAddress: req.ip,
    correlationId: req.correlationId
  });

  return student;
}
```

## Role-Based Access Control (RBAC)

### Role Hierarchy

```
ADMIN
  ↓ (has all permissions)
  ├── Student Management
  ├── Teacher Management
  ├── Academic Management
  ├── Fee Management
  ├── Audit Access
  └── System Configuration

TEACHER
  ↓ (limited to assigned resources)
  ├── Own Profile
  ├── Assigned Classes
  ├── Assigned Students (read-only)
  ├── Attendance (assigned classes)
  ├── Marks (assigned subjects)
  └── Assignments (assigned subjects)

STUDENT
  ↓ (limited to own resources)
  ├── Own Profile
  ├── Own Attendance
  ├── Own Marks
  ├── Own Fees
  ├── Own Assignments
  └── Own Timetable
```

### Permission Examples

```typescript
// Student permissions
const STUDENT_PERMISSIONS = [
  'student:profile:read',
  'student:profile:update',
  'student:attendance:read',
  'student:marks:read',
  'student:fees:read',
  'student:courses:read',
  'student:assignments:read',
  'student:assignments:submit',
  'student:exams:read',
  'student:timetable:read',
  'student:notifications:read',
];

// Teacher permissions
const TEACHER_PERMISSIONS = [
  'teacher:profile:read',
  'teacher:profile:update',
  'teacher:students:read', // Only assigned
  'teacher:attendance:create',
  'teacher:attendance:update',
  'teacher:marks:create',
  'teacher:marks:update',
  'teacher:assignments:create',
  'teacher:assignments:update',
  'teacher:assignments:delete',
  'teacher:assignments:grade',
  'teacher:subjects:read',
  'teacher:classes:read',
  'teacher:timetable:read',
];

// Admin permissions
const ADMIN_PERMISSIONS = [
  'admin:students:create',
  'admin:students:read',
  'admin:students:update',
  'admin:students:delete',
  'admin:students:approve',
  'admin:students:reject',
  'admin:students:suspend',
  'admin:teachers:create',
  'admin:teachers:read',
  'admin:teachers:update',
  'admin:teachers:delete',
  'admin:teachers:approve',
  'admin:teachers:reject',
  'admin:teachers:suspend',
  'admin:departments:manage',
  'admin:courses:manage',
  'admin:subjects:manage',
  'admin:classes:manage',
  'admin:timetables:manage',
  'admin:exams:manage',
  'admin:fees:manage',
  'admin:announcements:manage',
  'admin:audit:read',
];
```

## Frontend Guards

### AuthGuard

```typescript
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private authService: AuthService,
    private router: Router,
  ) {}

  canActivate(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot,
  ): boolean {
    if (this.authService.isAuthenticated()) {
      return true;
    }

    // Store attempted URL for redirect after login
    this.router.navigate(['/login'], {
      queryParams: { returnUrl: state.url },
    });
    return false;
  }
}
```

### RoleGuard

```typescript
@Injectable()
export class RoleGuard implements CanActivate {
  constructor(
    private authService: AuthService,
    private router: Router,
  ) {}

  canActivate(route: ActivatedRouteSnapshot): boolean {
    const requiredRole = route.data['role'] as string;
    const user = this.authService.getCurrentUser();

    if (user && user.role === requiredRole) {
      return true;
    }

    this.router.navigate(['/unauthorized']);
    return false;
  }
}
```

### ApprovalGuard

```typescript
@Injectable()
export class ApprovalGuard implements CanActivate {
  constructor(
    private authService: AuthService,
    private router: Router,
  ) {}

  canActivate(): boolean {
    const user = this.authService.getCurrentUser();

    if (!user) {
      this.router.navigate(['/login']);
      return false;
    }

    if (user.status === 'PENDING') {
      this.router.navigate(['/pending-approval']);
      return false;
    }

    if (user.status === 'REJECTED') {
      this.router.navigate(['/registration-rejected']);
      return false;
    }

    if (user.status === 'SUSPENDED') {
      this.router.navigate(['/account-suspended']);
      return false;
    }

    return true;
  }
}
```

### Route Configuration

```typescript
const routes: Routes = [
  {
    path: 'student',
    canActivate: [AuthGuard, RoleGuard, ApprovalGuard],
    data: { role: 'STUDENT' },
    loadChildren: () => loadRemoteModule({...})
  },
  {
    path: 'teacher',
    canActivate: [AuthGuard, RoleGuard, ApprovalGuard],
    data: { role: 'TEACHER' },
    loadChildren: () => loadRemoteModule({...})
  },
  {
    path: 'admin',
    canActivate: [AuthGuard, RoleGuard, ApprovalGuard],
    data: { role: 'ADMIN' },
    loadChildren: () => loadRemoteModule({...})
  }
];
```

## HTTP Interceptor

```typescript
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(
    private authService: AuthService,
    private router: Router,
  ) {}

  intercept(
    req: HttpRequest<any>,
    next: HttpHandler,
  ): Observable<HttpEvent<any>> {
    const accessToken = this.authService.getAccessToken();

    // Add Authorization header if token exists
    if (accessToken) {
      req = req.clone({
        setHeaders: {
          Authorization: `Bearer ${accessToken}`,
        },
      });
    }

    return next.handle(req).pipe(
      catchError((error: HttpErrorResponse) => {
        if (error.status === 401) {
          // Access token expired, try refresh
          return this.handle401Error(req, next);
        }

        if (error.status === 403) {
          // Forbidden - user doesn't have permission
          this.router.navigate(['/unauthorized']);
        }

        return throwError(() => error);
      }),
    );
  }

  private handle401Error(
    req: HttpRequest<any>,
    next: HttpHandler,
  ): Observable<HttpEvent<any>> {
    return this.authService.refreshToken().pipe(
      switchMap((tokens) => {
        // Retry original request with new token
        req = req.clone({
          setHeaders: {
            Authorization: `Bearer ${tokens.accessToken}`,
          },
        });
        return next.handle(req);
      }),
      catchError((err) => {
        // Refresh failed, logout user
        this.authService.logout();
        this.router.navigate(['/login']);
        return throwError(() => err);
      }),
    );
  }
}
```

## Password Security

### Password Requirements

```typescript
const PASSWORD_REQUIREMENTS = {
  minLength: 8,
  maxLength: 128,
  requireUppercase: true,
  requireLowercase: true,
  requireDigit: true,
  requireSpecialChar: true,
  specialChars: '!@#$%^&*()_+-=[]{}|;:,.<>?',
};
```

**Validation:**

```regex
^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,128}$
```

### Password Hashing

```typescript
import * as argon2 from 'argon2';

async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 65536, // 64 MB
    timeCost: 3, // 3 iterations
    parallelism: 4, // 4 threads
  });
}

async function verifyPassword(
  hash: string,
  password: string,
): Promise<boolean> {
  return argon2.verify(hash, password);
}
```

## Security Best Practices

### ✅ DO

1. **Always verify authorization in backend services**
   - Frontend guards are UX only
   - Backend must independently authorize every request

2. **Use short-lived access tokens**
   - 15 minutes max
   - Forces periodic refresh

3. **Rotate refresh tokens**
   - One-time use
   - Revoke old token immediately

4. **Hash refresh tokens before storage**
   - Store SHA-256 hash, not plaintext
   - Prevents database leak exploitation

5. **Audit sensitive operations**
   - Log all admin actions
   - Log all data modifications
   - Include correlation ID for tracing

6. **Implement rate limiting**
   - Prevent brute force attacks
   - Lock accounts after failed attempts

7. **Validate token on every request**
   - Check signature
   - Check expiration
   - Check user status

### ❌ DON'T

1. **Never trust client-provided user IDs**

   ```typescript
   // BAD
   @Post('/students/:id/marks')
   async addMarks(@Param('id') studentId: number) {
     // Student could change URL to access others
   }

   // GOOD
   @Post('/students/me/marks')
   async addMarks(@User() user: AuthUser) {
     const studentId = user.studentId; // From JWT
   }
   ```

2. **Never rely only on frontend authorization**

   ```typescript
   // Frontend hiding button ≠ Backend authorization
   ```

3. **Never expose stack traces to clients**

   ```typescript
   // BAD
   return res.status(500).json({ error: err.stack });

   // GOOD
   return res.status(500).json({ error: 'Internal server error' });
   ```

4. **Never log sensitive data**

   ```typescript
   // BAD
   logger.info('Login attempt', { password: req.body.password });

   // GOOD
   logger.info('Login attempt', { email: req.body.email });
   ```

5. **Never use synchronous password hashing**
   ```typescript
   // BAD (blocks event loop)
   const hash = bcrypt.hashSync(password, 10);

   // GOOD
   const hash = await argon2.hash(password);
   ```

## Session Management

### Access Token Storage

- **Memory/State**: Cleared on page reload (acceptable for 15-min tokens)
- **Never localStorage**: XSS-vulnerable
- **Never sessionStorage**: XSS-vulnerable

### Refresh Token Storage

- **HttpOnly Cookie**: Cannot be accessed by JavaScript (XSS-safe)
- **Secure Flag**: Only sent over HTTPS
- **SameSite=Strict**: CSRF protection

### Token Cleanup

```typescript
// Periodically clean expired/revoked tokens
@Cron('0 0 * * *') // Daily at midnight
async cleanupTokens() {
  await this.refreshTokenRepo.delete({
    where: [
      { expiresAt: LessThan(new Date()) },
      { revoked: true }
    ]
  });
}
```

## Multi-Device Support

Users can be logged in on multiple devices:

- Each device gets its own refresh token
- Logout revokes only current device's token
- "Logout all devices" revokes all user's tokens

```typescript
// Logout current device
async logout(refreshToken: string) {
  await this.revokeToken(refreshToken);
}

// Logout all devices
async logoutAll(userId: number) {
  await this.refreshTokenRepo.update(
    { userId, revoked: false },
    { revoked: true, revokedAt: new Date() }
  );
}
```

## Remember Me

Optional "Remember Me" extends refresh token expiry:

- Default: 7 days
- Remember Me: 30 days

```typescript
const refreshTokenExpiry = rememberMe
  ? 30 * 24 * 60 * 60 // 30 days
  : 7 * 24 * 60 * 60; // 7 days
```
