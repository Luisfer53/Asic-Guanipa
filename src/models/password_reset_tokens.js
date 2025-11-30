'use strict';
const {
  Model
} = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class password_reset_tokens extends Model {
    /**
     * Helper method for defining associations.
     * This method is not a part of Sequelize lifecycle.
     * The `models/index` file will call this method automatically.
     */
    static associate(models) {
      // define association here
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
  });
  return password_reset_tokens;
};