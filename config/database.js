require('dotenv').config();

const sslConfig = {
  ssl: {
    require: true,
    rejectUnauthorized: false
  }
};

const isSslEnabled = () => {
  if (process.env.DB_SSL === 'true') return true;
  if (process.env.DB_SSL === 'false') return false;
  const dbUrl = process.env.DATABASE_URL || '';
  if (dbUrl.includes('supabase.co') || dbUrl.includes('supabase.com') || dbUrl.includes('pooler.supabase.com')) return true;
  if (dbUrl.includes('render.com')) return true;
  if (dbUrl.includes('sslmode=require')) return true;
  if (process.env.NODE_ENV === 'production' && dbUrl) return true;
  return false;
};

module.exports = {
  development: {
    use_env_variable: process.env.DATABASE_URL ? "DATABASE_URL" : undefined,
    url: process.env.DATABASE_URL,
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
    use_env_variable: process.env.DATABASE_URL ? "DATABASE_URL" : undefined,
    url: process.env.DATABASE_URL,
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 5432,
    dialect: "postgres",
    dialectOptions: isSslEnabled() ? sslConfig : {}
  }
};
