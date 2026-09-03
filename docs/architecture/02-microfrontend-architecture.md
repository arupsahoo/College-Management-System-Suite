# Microfrontend Architecture

## Overview

The College Management System uses **Angular Module Federation** to create independently deployable, lazy-loadable microfrontends.

## Architecture Pattern

```
┌───────────────────────────────────────────────────────────────┐
│                    college-shell (Host)                        │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   Header     │  │  Sidebar     │  │   Profile    │        │
│  │  Component   │  │  Navigation  │  │    Menu      │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐     │
│  │            Router Outlet (Main Content)             │     │
│  │                                                      │     │
│  │  Routes:                                            │     │
│  │  /login       → Login Component (Shell)             │     │
│  │  /student/*   → student-mfe (Remote)                │     │
│  │  /teacher/*   → teacher-mfe (Remote)                │     │
│  │  /admin/*     → admin-mfe (Remote)                  │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  Auth State  │  │ Notification │  │    Global    │        │
│  │   Service    │  │   Service    │  │    Error     │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└───────────────────────────────────────────────────────────────┘
         │                    │                    │
         │ Loads Remotely     │                    │
         ▼                    ▼                    ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│  student-mfe   │  │  teacher-mfe   │  │   admin-mfe    │
│                │  │                │  │                │
│ Exposes:       │  │ Exposes:       │  │ Exposes:       │
│ StudentModule  │  │ TeacherModule  │  │ AdminModule    │
│                │  │                │  │                │
│ Routes:        │  │ Routes:        │  │ Routes:        │
│ /dashboard     │  │ /dashboard     │  │ /dashboard     │
│ /profile       │  │ /profile       │  │ /students      │
│ /attendance    │  │ /attendance    │  │ /teachers      │
│ /courses       │  │ /students      │  │ /departments   │
│ /marks         │  │ /subjects      │  │ /courses       │
│ /fees          │  │ /marks         │  │ /subjects      │
│ /assignments   │  │ /assignments   │  │ /attendance    │
│ /exams         │  │ /timetable     │  │ /exams         │
│ /timetable     │  │ /announcements │  │ /fees          │
└────────────────┘  └────────────────┘  └────────────────┘
```

## Module Federation Configuration

### Shell Application (Host)

**Responsibilities:**

- Bootstrap the application
- Provide authentication shell
- Render global navigation (header, sidebar, user menu)
- Load remote MFEs based on user role
- Manage global state (authenticated user, permissions, notifications)
- Provide shared UI components
- Handle global error boundaries
- Manage SSR rendering

**Exposes:** None (it's the host)

**Remotes:**

```typescript
remotes: {
  'student-mfe': 'http://localhost:4201/remoteEntry.js',
  'teacher-mfe': 'http://localhost:4202/remoteEntry.js',
  'admin-mfe': 'http://localhost:4203/remoteEntry.js'
}
```

**Shared Dependencies:**

```typescript
shared: {
  '@angular/core': { singleton: true, strictVersion: true },
  '@angular/common': { singleton: true, strictVersion: true },
  '@angular/router': { singleton: true, strictVersion: true },
  '@angular/forms': { singleton: true },
  '@angular/material': { singleton: true },
  'rxjs': { singleton: true },
  '@cms/shared-ui': { singleton: true },
  '@cms/shared-models': { singleton: true },
  '@cms/shared-auth': { singleton: true }
}
```

### Student MFE (Remote)

**Exposes:**

```typescript
exposes: {
  './Module': './src/app/student/student.module.ts'
}
```

**Routes Prefix:** `/student`

**Components:**

- StudentDashboardComponent
- StudentProfileComponent
- StudentAttendanceComponent
- StudentCoursesComponent
- StudentMarksComponent
- StudentFeesComponent
- StudentAssignmentsComponent
- StudentExamsComponent
- StudentTimetableComponent
- StudentNotificationsComponent

**Facades:**

- StudentFacade
- AttendanceFacade
- MarksFacade
- FeesFacade

### Teacher MFE (Remote)

**Exposes:**

```typescript
exposes: {
  './Module': './src/app/teacher/teacher.module.ts'
}
```

**Routes Prefix:** `/teacher`

**Components:**

- TeacherDashboardComponent
- TeacherProfileComponent
- TeacherAttendanceComponent
- TeacherStudentsComponent
- TeacherSubjectsComponent
- TeacherMarksComponent
- TeacherAssignmentsComponent
- TeacherTimetableComponent
- TeacherAnnouncementsComponent

**Facades:**

- TeacherFacade
- StudentManagementFacade
- AttendanceManagementFacade
- MarksManagementFacade
- AssignmentManagementFacade

### Admin MFE (Remote)

**Exposes:**

```typescript
exposes: {
  './Module': './src/app/admin/admin.module.ts'
}
```

**Routes Prefix:** `/admin`

**Components:**

- AdminDashboardComponent
- StudentManagementComponent
- TeacherManagementComponent
- DepartmentManagementComponent
- CourseManagementComponent
- SubjectManagementComponent
- ClassManagementComponent
- TimetableManagementComponent
- AttendanceManagementComponent
- ExamManagementComponent
- FeeManagementComponent
- AnnouncementManagementComponent
- AuditLogComponent

**Facades:**

- AdminFacade
- UserManagementFacade
- AcademicManagementFacade
- AttendanceAdminFacade
- ExamAdminFacade
- FeeAdminFacade

## Shared Libraries

### @cms/shared-ui

Common UI components used across MFEs:

- Button, Input, Select, Checkbox, Radio
- Modal, Dialog, Drawer
- Table, Pagination
- DatePicker, TimePicker
- FileUpload
- LoadingSpinner, Skeleton
- Toast/Snackbar
- ConfirmDialog
- EmptyState, ErrorState
- Card, Badge, Chip
- Avatar, ProfilePicture

### @cms/shared-models

TypeScript interfaces/types:

- User, Student, Teacher, Admin
- Course, Subject, Department
- Attendance, Marks, Fees
- Assignment, Exam
- Notification, Announcement
- API Response types
- Pagination, Filter, Sort types

### @cms/shared-auth

Authentication utilities:

- AuthService
- TokenService
- AuthGuard
- RoleGuard
- PermissionGuard
- AuthInterceptor
- Token refresh logic

### @cms/shared-utils

Utility functions:

- Date formatting
- Validators
- Form helpers
- Error handlers
- Storage wrappers (SSR-safe)

### @cms/shared-validation

Validation schemas and validators:

- Email, phone validators
- Password strength
- File type/size validators
- Custom validators

## Route Guards & Security

### AuthGuard

Checks if user is authenticated. Redirects to `/login` if not.

### RoleGuard

Checks if user has required role:

- `/student/*` → Requires `STUDENT` role
- `/teacher/*` → Requires `TEACHER` role
- `/admin/*` → Requires `ADMIN` role

### ApprovalGuard

Checks if user is approved:

- `PENDING` users → Redirected to pending-approval page
- `REJECTED` users → Redirected to rejection notice
- `SUSPENDED` users → Redirected to suspension notice

## Lazy Loading Strategy

```typescript
// Shell routing
const routes: Routes = [
  { path: 'login', component: LoginComponent },
  {
    path: 'student',
    canActivate: [AuthGuard, RoleGuard, ApprovalGuard],
    data: { role: 'STUDENT' },
    loadChildren: () =>
      loadRemoteModule({
        type: 'module',
        remoteEntry: 'http://localhost:4201/remoteEntry.js',
        exposedModule: './Module',
      }),
  },
  {
    path: 'teacher',
    canActivate: [AuthGuard, RoleGuard, ApprovalGuard],
    data: { role: 'TEACHER' },
    loadChildren: () =>
      loadRemoteModule({
        type: 'module',
        remoteEntry: 'http://localhost:4202/remoteEntry.js',
        exposedModule: './Module',
      }),
  },
  {
    path: 'admin',
    canActivate: [AuthGuard, RoleGuard, ApprovalGuard],
    data: { role: 'ADMIN' },
    loadChildren: () =>
      loadRemoteModule({
        type: 'module',
        remoteEntry: 'http://localhost:4203/remoteEntry.js',
        exposedModule: './Module',
      }),
  },
];
```

## SSR Considerations

1. **Platform Checks**: Use `isPlatformBrowser()` and `isPlatformServer()` for browser-only APIs
2. **Transfer State**: Share data fetched during SSR to avoid re-fetching on client
3. **Avoid Direct DOM Access**: No `window`, `document`, `localStorage` directly in constructors/onInit
4. **HTTP in SSR**: All HTTP calls must work server-side (use absolute URLs or proxy)
5. **Module Federation in SSR**: Shell renders server-side; remotes load client-side

## Build & Deployment

Each MFE builds independently:

```bash
# Build all
npm run build:all

# Or individually
npm run build:shell
npm run build:student-mfe
npm run build:teacher-mfe
npm run build:admin-mfe
```

**Deployment:**

- Each MFE deployed to separate path/subdomain
- Shell references remotes via environment-based URLs
- Production uses CDN URLs; dev uses localhost

## Version Management

Remote entries include version hash in production:

```
http://cdn.example.com/student-mfe/v1.2.3/remoteEntry.js
```

Shell's `remotes` configuration comes from environment config, enabling zero-downtime updates.

## Communication Between MFEs

MFEs do NOT directly communicate. Instead:

1. **Via Shell**: Shell manages global state (auth, notifications)
2. **Via API**: Each MFE calls backend APIs independently
3. **Via Events**: Shell provides event bus for cross-MFE messaging (rare)

Example: Teacher creates announcement → Notification service → WebSocket/polling → Shell updates notification count → Student MFE shows badge.

## Development Mode

Run all MFEs concurrently:

```bash
npm run start:all
```

This starts:

- Shell on 4200
- Student MFE on 4201
- Teacher MFE on 4202
- Admin MFE on 4203

Hot reload works independently per MFE.
