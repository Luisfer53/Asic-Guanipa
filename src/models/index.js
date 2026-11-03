'use strict';

const fs = require('fs');
const path = require('path');
const Sequelize = require('sequelize');
const process = require('process');
const basename = path.basename(__filename);
const env = process.env.NODE_ENV || 'development';

const config = require(__dirname + '/../../config/database.js')[env];
const db = {};

let sequelize;
const dbUrlToUse = config.url || (process.env.DATABASE_URL ? process.env.DATABASE_URL.replace(/[?&]sslmode=[^&]+/g, '').replace(/[?&]ssl=[^&]+/g, '').replace(/\?$/, '') : undefined);

if (config.use_env_variable && process.env[config.use_env_variable]) {
    sequelize = new Sequelize(process.env[config.use_env_variable], config);
} else if (dbUrlToUse) {
    sequelize = new Sequelize(dbUrlToUse, config);
} else {
    sequelize = new Sequelize(config.database, config.username, config.password, config);
}

// Asegurar que rejectUnauthorized: false esté activo para evitar errores de certificados en cloud
if (config.dialectOptions && config.dialectOptions.ssl) {
    if (sequelize.config && sequelize.config.dialectOptions) {
        sequelize.config.dialectOptions.ssl = { require: true, rejectUnauthorized: false };
    }
    if (sequelize.connectionManager && sequelize.connectionManager.config && sequelize.connectionManager.config.dialectOptions) {
        sequelize.connectionManager.config.dialectOptions.ssl = { require: true, rejectUnauthorized: false };
    }
}

fs
    .readdirSync(__dirname)
    .filter(file => {
        return (
            file.indexOf('.') !== 0 &&
            file !== basename &&
            file.slice(-3) === '.js' &&
            file.indexOf('.test.js') === -1
        );
    })
    .forEach(file => {
        const model = require(path.join(__dirname, file))(sequelize, Sequelize.DataTypes);
        // Los archivos deprecated (como users.js) devuelven undefined — se omiten
        if (model) {
            db[model.name] = model;
        }
    });

Object.keys(db).forEach(modelName => {
    if (db[modelName].associate) {
        db[modelName].associate(db);
    }
});

db.sequelize = sequelize;
db.Sequelize = Sequelize;

module.exports = db;
