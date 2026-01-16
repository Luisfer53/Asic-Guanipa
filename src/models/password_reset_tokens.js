'use strict';
const {
  Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class password_reset_tokens extends Model {

    static associate(models) {

    }
  }
  password_reset_tokens.init({
    user_id: DataTypes.BIGINT,
    token: DataTypes.STRING,
    expires_at: DataTypes.DATE,
    used: DataTypes.BOOLEAN
  }, {
    sequelize,
    modelName: 'password_reset_tokens',
    underscored: true,
  });
  return password_reset_tokens;
};