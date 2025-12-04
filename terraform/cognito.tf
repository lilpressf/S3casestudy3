############################
# Cognito for portal auth  #
############################

resource "random_id" "cognito_domain" {
  byte_length = 4
}

resource "aws_cognito_user_pool" "portal" {
  name = "innovatech-portal"

  password_policy {
    minimum_length    = 10
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "portal" {
  name                                 = "innovatech-portal-client"
  user_pool_id                         = aws_cognito_user_pool.portal.id
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true

  # stable domain-based URLs
  callback_urls = [
    "https://portal.daanwelten.nl/oauth2/idpresponse",
    "http://localhost/"                   # keep for local testing
  ]

  logout_urls = [
    "https://portal.daanwelten.nl/logout",
    "http://localhost/"                   # keep for local testing
  ]

  supported_identity_providers = ["COGNITO"]
  generate_secret              = true
}

resource "aws_cognito_user_pool_domain" "portal" {
  domain       = "innovatech-${random_id.cognito_domain.hex}"
  user_pool_id = aws_cognito_user_pool.portal.id
}
