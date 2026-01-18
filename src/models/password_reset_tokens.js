'use strict';
const {
  Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class PasswordResetToken extends Model {
    static associate(models) {
    }
  }
  PasswordResetToken.init({
    user_id: DataTypes.BIGINT,
    token: DataTypes.STRING,
    expires_at: DataTypes.DATE,
    used: DataTypes.BOOLEAN
  }, {
    sequelize,
    modelName: 'PasswordResetToken',
    tableName: 'password_reset_tokens',
    underscored: true,
  });
  return PasswordResetToken;
};