-- =============================================================
-- Complete Seed Script: Roles + Tenants + Users
-- =============================================================

-- 1. SEED ROLES
INSERT IGNORE INTO roles (role_id, role_code, role_name) VALUES
(1, 'ADMIN', 'Administrator'),
(2, 'INVESTIGATOR', 'Claim Investigator'),
(3, 'USER', 'Customer / Policy Holder');

-- 2. SEED TENANTS
INSERT IGNORE INTO tenants (tenant_id, tenant_code, name, status) VALUES
(1, 'TATA_AIG', 'Tata AIG General Insurance', 'ACTIVE'),
(2, 'MAHI', 'Mahindra Insurance Brokers', 'ACTIVE'),
(3, 'MSIL', 'Maruti Suzuki Insurance', 'ACTIVE');

-- 3. SEED ADMIN USER (Password: Admin@2026)
INSERT INTO users (
    avatar_url, created_at, deleted_at, email, email_verified_at,
    full_name, is_deleted, last_login, password_hash, status,
    updated_at, role_id, tenant_id
) VALUES (
    NULL, NOW(), NULL, 'admin@fraudguard.com', NOW(),
    'System Administrator', 0, NULL,
    '$2b$10$tAoet3lKxWkaaODdlOcmW.iuHkwsktnpq9SVt.xauJ94aSqCTnQ6u',
    'ACTIVE', NOW(), 1, 1
) ON DUPLICATE KEY UPDATE updated_at = NOW();

-- 4. SEED INVESTIGATORS (Password: Investigator@2026)
INSERT INTO users (avatar_url, created_at, deleted_at, email, email_verified_at, full_name, is_deleted, last_login, password_hash, status, updated_at, role_id, tenant_id)
VALUES 
(NULL, NOW(), NULL, 'investigator01@fraudguard.com', NOW(), 'Arjun Sharma',    0, NULL, '$2b$10$IIyHf3NHTJMYxEnl2BKsSubEMBpj6BT9vwqMXheo0ywKXkX7bFrUO', 'ACTIVE', NOW(), 2, 1),
(NULL, NOW(), NULL, 'investigator02@fraudguard.com', NOW(), 'Priya Verma',     0, NULL, '$2b$10$8cMdKn3TDiZHivsuwTx5O.wjA7fZvyI28Wybd2WrrVUmMBbhPBbB2', 'ACTIVE', NOW(), 2, 1),
(NULL, NOW(), NULL, 'investigator03@fraudguard.com', NOW(), 'Rohan Mehta',     0, NULL, '$2b$10$g/cB0k4OEF1.u9Sxrv2wJ.zo7S2fkHFMHPIZkhc3DgkvnBAwMU5x2', 'ACTIVE', NOW(), 2, 1),
(NULL, NOW(), NULL, 'investigator04@fraudguard.com', NOW(), 'Sneha Patil',     0, NULL, '$2b$10$6VY13SBjJmzGA7UlAjtiuO8UeNPw0v2WlinNI9ALl8cFy2LIvvTe6', 'ACTIVE', NOW(), 2, 2),
(NULL, NOW(), NULL, 'investigator05@fraudguard.com', NOW(), 'Karan Singh',     0, NULL, '$2b$10$dH6Ch.njPiqdvnM8lum2cOKFT2w2Ld4afmgIc.KfblTqFSWRXneAK', 'ACTIVE', NOW(), 2, 2),
(NULL, NOW(), NULL, 'investigator06@fraudguard.com', NOW(), 'Ananya Joshi',    0, NULL, '$2b$10$WCo7chGssDarADVYa8NG8.74F5z.iwGKyUxbXVdf4uSFJxpIsWAPG', 'ACTIVE', NOW(), 2, 2),
(NULL, NOW(), NULL, 'investigator07@fraudguard.com', NOW(), 'Vikram Nair',     0, NULL, '$2b$10$9zoFD/g/1V0EXwvtVMc9m.4AiHbcINzrAcgPeGQpJLahaJHO6.Cpm', 'ACTIVE', NOW(), 2, 3),
(NULL, NOW(), NULL, 'investigator08@fraudguard.com', NOW(), 'Divya Reddy',     0, NULL, '$2b$10$/c4O8jXGl7UAHG/vJ5JfNeUGeHvB57oeZ/flcyrhFKOVlroqNi.Ay', 'ACTIVE', NOW(), 2, 3),
(NULL, NOW(), NULL, 'investigator09@fraudguard.com', NOW(), 'Nikhil Desai',    0, NULL, '$2b$10$3rDEJadQBx12V0eltjK68uTpX6WQoOo8IT9XP669pCw5DNg5gn3G.', 'ACTIVE', NOW(), 2, 3),
(NULL, NOW(), NULL, 'investigator10@fraudguard.com', NOW(), 'Meera Kulkarni',  0, NULL, '$2b$10$JqxPmRFrmTjpir6N7G4k3uRKs4HVO/U27DK0GvGtqcQAXbm4DOy/C', 'ACTIVE', NOW(), 2, 3)
ON DUPLICATE KEY UPDATE updated_at = NOW();

-- 5. VERIFY
SELECT u.user_id, u.full_name, u.email, r.role_code, t.tenant_code, u.status
FROM users u
JOIN roles r   ON r.role_id   = u.role_id
JOIN tenants t ON t.tenant_id = u.tenant_id
ORDER BY r.role_id, u.user_id;
