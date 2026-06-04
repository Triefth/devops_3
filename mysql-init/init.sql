CREATE DATABASE IF NOT EXISTS despachosdb;
CREATE DATABASE IF NOT EXISTS ventasdb;

-- Esto es vital: otorga permisos al usuario sobre ambas DBs
GRANT ALL PRIVILEGES ON despachosdb.* TO 'userdb'@'%';
GRANT ALL PRIVILEGES ON ventasdb.* TO 'userdb'@'%';
FLUSH PRIVILEGES;