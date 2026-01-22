'use strict';
const {
  Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class User extends Model {
    static associate(models) {
      User.belongsToMany(models.Role, {
        through: 'user_roles',
        foreignKey: 'username',
        sourceKey: 'username',
        otherKey: 'role_id',
        as: 'roles'
      });
    }
  }
  User.init({
    username: {
      type: DataTypes.STRING,
      unique: true,
      allowNull: false
    },
    email: {
      type: DataTypes.STRING,
      unique: true,
      allowNull: false
    },
    password: DataTypes.STRING
  }, {
    sequelize,
    modelName: 'User',
    underscored: true,
    timestamps: true
  });
  return User;
};