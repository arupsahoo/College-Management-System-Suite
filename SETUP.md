# College Management System - Setup Guide

This guide will help you set up and run the College Management System locally.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js**: v20.x or higher ([Download](https://nodejs.org/))
- **npm**: v10.x or higher (comes with Node.js)
- **MySQL**: v8.0 or higher ([Download](https://dev.mysql.com/downloads/))
- **Git**: Latest version ([Download](https://git-scm.com/))
- **Docker** (Optional): For containerized deployment ([Download](https://www.docker.com/))

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd college-management-system-suite
```

### 2. Install Dependencies

```bash
npm install --legacy-peer-deps
```

**Note:** We use `--legacy-peer-deps` to handle Angular version conflicts during development.

### 3. Set Up Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and update the values (especially database credentials and JWT secrets)
```

**Important:** Generate strong JWT secrets for production:

```bash
# Generate JWT secrets
openssl rand -base64 64
```

### 4. Set Up MySQL Databases

#### Option A: Manual Setup

```bash
# Login to MySQL
mysql -u root -p

# Run the initialization script
source database/init.sql
```

#### Option B: Using Docker

```bash
# Start only MySQL
docker-compose up mysql -d

# Wait for MySQL to be ready (check with)
docker-compose ps
```

### 5. Run Database Migrations

**Note:** Migrations will be implemented in Phase 3. For now, databases are created empty.

```bash
# Future: Run migrations
# npm run migrate
```

### 6. Start Development Servers

#### Option A: Start All Services

```bash
# Start all Angular apps and Node.js services
npm run start:all
```

This will start:
- API Gateway: http://localhost:3000
- Auth Service: http://localhost:3001
- Student Service: http://localhost:3002
- Teacher Service: http://localhost:3003
- Admin Service: http://localhost:3004
- Notification Service: http://localhost:3005
- File Service: http://localhost:3006
- Audit Service: http://localhost:3007
- College Shell: http://localhost:4200
- Student MFE: http://localhost:4201
- Teacher MFE: http://localhost:4202
- Admin MFE: http://localhost:4203

#### Option B: Start Services Separately

Start frontend applications:
```bash
npm run start:apps
```

Start backend services:
```bash
npm run start:services
```

Start individual services:
```bash
# Start college-shell
npx nx serve college-shell

# Start API Gateway
npx nx serve api-gateway

# Start auth-service
npx nx serve auth-service
```

### 7. Access the Application

- **Frontend:** http://localhost:4200
- **API Gateway:** http://localhost:3000

## Docker Setup (Alternative)

### Using Docker Compose

```bash
# Build and start all services
docker-compose up --build

# Or run in detached mode
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Individual Service Docker Build

```bash
# Build specific service
docker-compose build api-gateway

# Start specific service
docker-compose up api-gateway
```

## Project Structure

```
college-management-system-suite/
│
├── apps/                          # Angular applications
│   ├── college-shell/             # Host application (Port 4200)
│   ├── student-mfe/               # Student microfrontend (Port 4201)
│   ├── teacher-mfe/               # Teacher microfrontend (Port 4202)
│   └── admin-mfe/                 # Admin microfrontend (Port 4203)
│
├── services/                      # Node.js microservices
│   ├── api-gateway/               # API Gateway (Port 3000)
│   ├── auth-service/              # Authentication (Port 3001)
│   ├── student-service/           # Student operations (Port 3002)
│   ├── teacher-service/           # Teacher operations (Port 3003)
│   ├── admin-service/             # Admin operations (Port 3004)
│   ├── notification-service/      # Notifications (Port 3005)
│   ├── file-service/              # File management (Port 3006)
│   └── audit-service/             # Audit logging (Port 3007)
│
├── libs/                          # Shared libraries
│   ├── shared-ui/                 # UI components
│   ├── shared-models/             # TypeScript interfaces
│   ├── shared-auth/               # Auth utilities
│   ├── shared-utils/              # Utility functions
│   └── shared-validation/         # Validation schemas
│
├── database/                      # Database scripts
│   ├── init.sql                   # Database initialization
│   ├── migrations/                # Migration files (future)
│   └── seeds/                     # Seed data (future)
│
├── docker/                        # Docker configurations
│   └── *.Dockerfile               # Service Dockerfiles
│
├── docs/                          # Documentation
│   ├── architecture/              # Architecture docs
│   ├── api/                       # API documentation
│   └── database/                  # Database docs
│
├── .env.example                   # Environment template
├── .env                           # Environment variables (not in git)
├── docker-compose.yml             # Docker Compose config
├── nx.json                        # Nx configuration
├── package.json                   # Dependencies
└── README.md                      # Project README
```

## Development Workflow

### Running Tests

```bash
# Run all tests
npm run test:all

# Run tests for specific project
npx nx test college-shell
npx nx test auth-service
```

### Linting

```bash
# Lint all projects
npm run lint:all

# Lint specific project
npx nx lint college-shell
```

### Formatting

```bash
# Check formatting
npm run format:check

# Fix formatting
npm run format:write
```

### Building for Production

```bash
# Build all projects
npm run build:all

# Build specific project
npx nx build college-shell --prod
npx nx build api-gateway --prod
```

## Common Issues

### Port Already in Use

If you get a "port already in use" error:

```bash
# Find process using port (example for port 4200)
# Windows
netstat -ano | findstr :4200

# Linux/Mac
lsof -i :4200

# Kill the process or change the port in .env
```

### Cannot Connect to MySQL

1. Ensure MySQL is running
2. Check credentials in `.env`
3. Verify database exists:
   ```bash
   mysql -u root -p -e "SHOW DATABASES;"
   ```

### Dependency Conflicts

If you encounter dependency conflicts:

```bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install --legacy-peer-deps
```

### TypeScript Project Reference Warning

If you see TypeScript project reference warnings:

```bash
# Set environment variable
export NX_IGNORE_UNSUPPORTED_TS_SETUP=true

# Or add to .env
NX_IGNORE_UNSUPPORTED_TS_SETUP=true
```

## Environment Variables

Key environment variables you should configure:

### Required
- `DB_HOST` - MySQL host (default: localhost)
- `DB_PORT` - MySQL port (default: 3306)
- `DB_USERNAME` - MySQL username (default: root)
- `DB_PASSWORD` - MySQL password (default: root)
- `JWT_ACCESS_SECRET` - JWT access token secret (MUST CHANGE)
- `JWT_REFRESH_SECRET` - JWT refresh token secret (MUST CHANGE)

### Optional
- `NODE_ENV` - Environment (development/production)
- `LOG_LEVEL` - Logging level (debug/info/warn/error)
- `CORS_ORIGIN` - Allowed CORS origin
- `MAX_FILE_SIZE` - Maximum file upload size

See `.env.example` for complete list.

## Next Steps

Phase 2 (Infrastructure Setup) is now complete. Next steps:

1. **Phase 3: Authentication & Authorization**
   - Implement JWT authentication
   - Create login/register endpoints
   - Implement authorization middleware
   - Add role-based access control

2. **Phase 4: Student Module**
   - Implement student service
   - Create student UI components
   - Add attendance management
   - Implement marks system

3. **Phase 5: Teacher Module**
   - Implement teacher service
   - Create teacher UI components
   - Add class management
   - Implement grading system

For detailed implementation plan, see [Implementation Roadmap](docs/architecture/05-implementation-roadmap.md).

## Useful Commands

```bash
# View project graph
npx nx graph

# Show project details
npx nx show project college-shell

# Run specific target
npx nx run college-shell:serve
npx nx run api-gateway:build

# Clear Nx cache
npx nx reset

# Update dependencies
npm update

# Check for outdated packages
npm outdated
```

## Support

- **Documentation:** [docs/](docs/)
- **Issues:** Create an issue in the repository
- **Architecture:** See [docs/architecture/](docs/architecture/)
- **API Docs:** See [docs/api/api-contracts.md](docs/api/api-contracts.md)

## Security Notes

⚠️ **Important Security Reminders:**

1. Never commit `.env` file
2. Change default JWT secrets in production
3. Use strong MySQL passwords
4. Enable HTTPS in production
5. Regularly update dependencies
6. Review security audit: `npm audit`

---

**Status:** Phase 2 Complete ✅  
**Current:** Infrastructure Setup Complete  
**Next:** Phase 3 - Authentication & Authorization
