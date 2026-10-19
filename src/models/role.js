'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Role extends Model {
    static associate(models) {
      if (models.Usuario) {
        Role.belongsToMany(models.Usuario, {
          through: 'usuario_roles',
          foreignKey: 'id_rol',
          sourceKey: 'id_serial',
          otherKey: 'nombre_usuario',
          targetKey: 'nombre_usuario',
          as: 'usuarios'
        });
      }
    }
  }

  Role.init({
    id_serial: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    nombre_rol: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    name: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.nombre_rol;
      }
    },
    id: {
      type: DataTypes.VIRTUAL,
      get() {
        return this.id_serial;
      }
    },
    fecha_creacion: {
      type: DataTypes.DATE,
      allowNull: true
    },
    fecha_actualizacion: {
      type: DataTypes.DATE,
      allowNull: true
    }
  }, {
    sequelize,
    modelName: 'Role',
    tableName: 'roles',
    underscored: true,
    timestamps: false
  });

  return Role;
};