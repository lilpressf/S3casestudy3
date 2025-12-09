data "aws_cognito_user_pool" "portal" {
  name = "innovatech-portal"
}

data "aws_cognito_user_pool_client" "portal" {
  user_pool_id = data.aws_cognito_user_pool.portal.id
  client_id    = "68nlqmca9tb48urul3fpvu58e"
}