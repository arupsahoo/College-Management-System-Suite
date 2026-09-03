-- College Management System - Database Initialization Script
-- This script creates all required databases for the microservices

-- Create databases if they don't exist
CREATE DATABASE IF NOT EXISTS college_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS college_student CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS college_teacher CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS college_admin CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS college_notification CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS college_file CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS college_audit CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant privileges (for development only - restrict in production)
GRANT ALL PRIVILEGES ON college_auth.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON college_student.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON college_teacher.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON college_admin.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON college_notification.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON college_file.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON college_audit.* TO 'root'@'%';

FLUSH PRIVILEGES;

-- Display created databases
SHOW DATABASES;
