'use strict';
const {
  Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class Role extends Model {

    static associate(models) {
      Role.belongsToMany(models.User, {
        through: 'user_roles',
        foreignKey: 'role_id',
        otherKey: 'username',
        targetKey: 'username',
        as: 'users'
      });
    }
  }
  Role.init({
    name: DataTypes.STRING
  }, {

    sequelize,
    modelName: 'Role',
    underscored: true,
    timestamps: true
  });
  return Role;
};