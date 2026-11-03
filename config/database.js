require('dotenv').config();

const isSslEnabled = () => {
  if (process.env.DB_SSL === 'true') return true;
  if (process.env.DB_SSL === 'false') return false;
  const dbUrl = process.env.DATABASE_URL || '';
  if (dbUrl.includes('supabase.co') || dbUrl.includes('supabase.com') || dbUrl.includes('pooler.supabase.com')) return true;
  if (dbUrl.includes('render.com')) return true;
  if (dbUrl.includes('sslmode=')) return true;
  if (process.env.NODE_ENV === 'production' && dbUrl) return true;
  return false;
};

// Si SSL está habilitado para PostgreSQL cloud (Supabase, Render, etc.),
// deshabilitar la verificación estricta de cadenas de certificados autofirmados / intermedias en Node.js
if (isSslEnabled()) {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
}

const cleanDatabaseUrl = (rawUrl) => {
  if (!rawUrl) return rawUrl;
  return rawUrl
    .replace(/[?&]sslmode=[^&]+/g, '')
    .replace(/[?&]ssl=[^&]+/g, '')
    .replace(/\?$/, '');
};

const resolvedDbUrl = cleanDatabaseUrl(process.env.DATABASE_URL);

const sslConfig = {
  ssl: {
    require: true,
    rejectUnauthorized: false
  }
};

module.exports = {
  development: {
    use_env_variable: resolvedDbUrl ? undefined : undefined,
    url: resolvedDbUrl,
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST || '127.0.0.1',
    port: process.env.DB_PORT || 5432,
    dialect: "postgres",
    dialectOptions: isSslEnabled() ? sslConfig : {}
  },
  test: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.CI_DB_NAME || 'test_db',
    host: process.env.DB_HOST || '127.0.0.1',
    port: process.env.DB_PORT || 5432,
    dialect: "postgres"
  },
  production: {
    use_env_variable: resolvedDbUrl ? undefined : undefined,
    url: resolvedDbUrl,
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 5432,
    dialect: "postgres",
    dialectOptions: isSslEnabled() ? sslConfig : {}
  }
};
