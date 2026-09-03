# System Architecture

## Overview

The College Management System (CMS) is a distributed application built with:

- **Frontend**: Angular 19+ microfrontends using Module Federation
- **Backend**: Node.js + TypeScript microservices
- **Database**: MySQL 8.x (logical database-per-service)
- **Communication**: REST APIs via API Gateway; internal service-to-service via HTTP; event-driven via lightweight event bus (upgradeable to RabbitMQ/Kafka)

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENTS                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │  Browser  │  │  Tablet  │  │  Mobile  │  │   SSR    │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
└───────┼──────────────┼──────────────┼──────────────┼────────────┘
        │              │              │              │
        ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NGINX / REVERSE PROXY                         │
│              TLS Termination, Static Assets, CSP                │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ college-shell│  │  student-mfe │  │  teacher-mfe │
│   (Host)     │  │   (Remote)   │  │   (Remote)   │
│  Port 4200   │  │  Port 4201   │  │  Port 4202   │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       │     ┌───────────┘                 │
       │     │    ┌────────────────────────┘
       ▼     ▼    ▼
┌──────────────────────────────────────────┐
│              admin-mfe (Remote)          │
│               Port 4203                  │
└──────────────────┬───────────────────────┘
                   │
     All MFEs communicate via
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                       API GATEWAY                               │
│                       Port 3000                                 │
│                                                                 │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌─────────────┐ │
│  │   Routing  │ │  Auth      │ │   Rate     │ │  Request    │ │
│  │            │ │  Verify    │ │  Limiting  │ │  Validation │ │
│  └────────────┘ └────────────┘ └────────────┘ └─────────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌─────────────┐ │
│  │ Correlation│ │   CORS     │ │  Security  │ │   API       │ │
│  │    ID      │ │            │ │  Headers   │ │ Versioning  │ │
│  └────────────┘ └────────────┘ └────────────┘ └─────────────┘ │
└────────────────────────────┬────────────────────────────────────┘
                             │
          ┌──────────┬───────┼───────┬──────────┐
          ▼          ▼       ▼       ▼          ▼
   ┌───────────┐┌────────┐┌────────┐┌────────┐┌──────────┐
   │   Auth    ││Student ││Teacher ││ Admin  ││Notifica- │
   │  Service  ││Service ││Service ││Service ││tion Svc  │
   │ Port 3001 ││Pt 3002 ││Pt 3003 ││Pt 3004 ││ Pt 3005  │
   └─────┬─────┘└───┬────┘└───┬────┘└───┬────┘└────┬─────┘
         │          │         │         │          │
         │    ┌─────┘    ┌────┘    ┌────┘     ┌────┘
         ▼    ▼          ▼         ▼          ▼
   ┌───────────┐   ┌──────────┐  ┌──────────┐
   │   File    │   │  Audit   │  │  Exam    │
   │  Service  │   │  Service │  │  Service │
   │ Port 3006 │   │ Pt 3007  │  │ Pt 3008  │
   └─────┬─────┘   └────┬─────┘  └────┬─────┘
         │              │              │
         ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      MySQL 8.x                                  │
│                      Port 3306                                  │
│                                                                 │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌─────────────┐ │
│  │college_auth│ │college_    │ │college_    │ │college_     │ │
│  │            │ │student     │ │teacher     │ │admin        │ │
│  └────────────┘ └────────────┘ └────────────┘ └─────────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐                 │
│  │college_    │ │college_    │ │college_    │                 │
│  │notification│ │audit       │ │file        │                 │
│  └────────────┘ └────────────┘ └────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

## Design Principles

1. **Separation of Concerns**: Each service owns its domain; each MFE owns its UI module
2. **Defense in Depth**: Authorization enforced at gateway AND service level
3. **Database Per Service**: Logical separation via schemas; no cross-service direct DB access
4. **SSR-Safe**: All Angular code must be server-rendering compatible
5. **Event-Driven Ready**: Service boundaries designed for eventual event bus integration
6. **12-Factor App**: Configuration via environment, stateless services, disposable processes

## Communication Patterns

### Client → Backend

- All requests go through the API Gateway
- Gateway verifies JWT, attaches user context, routes to service

### Service → Service

- Synchronous: HTTP REST via internal service URLs
- Asynchronous: Event emitter (lightweight; upgradeable to message broker)

### Data Ownership

| Service              | Databases            | Owns                                                                              |
| -------------------- | -------------------- | --------------------------------------------------------------------------------- |
| auth-service         | college_auth         | users, roles, permissions, refresh_tokens                                         |
| student-service      | college_student      | students, enrollments, student_attendance, student_fees                           |
| teacher-service      | college_teacher      | teachers, teacher_assignments, teacher_attendance                                 |
| admin-service        | college_admin        | departments, courses, subjects, classes, timetables, rooms, exams, fee_structures |
| notification-service | college_notification | notifications, announcements                                                      |
| audit-service        | college_audit        | audit_logs                                                                        |
| file-service         | college_file         | files, file_metadata                                                              |

## Port Assignments

| Component                | Port |
| ------------------------ | ---- |
| college-shell (Host MFE) | 4200 |
| student-mfe              | 4201 |
| teacher-mfe              | 4202 |
| admin-mfe                | 4203 |
| API Gateway              | 3000 |
| Auth Service             | 3001 |
| Student Service          | 3002 |
| Teacher Service          | 3003 |
| Admin Service            | 3004 |
| Notification Service     | 3005 |
| File Service             | 3006 |
| Audit Service            | 3007 |
| Exam Service             | 3008 |
| MySQL                    | 3306 |

## Assumptions

1. Initial deployment is single-node; architecture supports horizontal scaling
2. File storage uses local filesystem initially; abstracted for S3/GCS migration
3. Email notifications are queued but actual sending uses a pluggable transport (console in dev)
4. SMS/push notification channels are designed as extension points
5. Rate limiting uses in-memory store initially; Redis can replace it
6. Session/token blacklist uses in-memory store initially; Redis can replace it
