'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Bitacora extends Model {
    static associate(models) {
      // Define associations if necessary
    }
  }
  Bitacora.init({
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    usuario: {
      type: DataTypes.STRING,
      allowNull: false
    },
    accion: {
      type: DataTypes.STRING,
      allowNull: false
    },
    tabla: {
      type: DataTypes.STRING,
      allowNull: false
    },
    detalles: {
      type: DataTypes.TEXT,
      allowNull: true
    }
  }, {
    sequelize,
    modelName: 'Bitacora',
    tableName: 'bitacora',
    underscored: true,
    timestamps: true,
  });
  return Bitacora;
};
