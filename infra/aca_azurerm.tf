resource "azurerm_user_assigned_identity" "azrmaca" {
  name                = provider::namep::namestring("azurerm_user_assigned_identity", local.namep_config, { name = "azrmaca" })
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

locals {
  azrmaca_app_name = provider::namep::namestring("azurerm_container_app", local.namep_config, { name = "azrmaca" })
}

resource "azurerm_container_app" "azrmaca" {
  name                         = local.azrmaca_app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.azrmaca.id]
  }

  registry {
    server   = data.azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.azrmaca.id
  }

  secret {
    name                = "microsoft-provider-authentication-secret"
    identity            = "System"
    key_vault_secret_id = azurerm_key_vault_secret.azrmaca_secret.id
  }

  secret {
    name                = "tokenstore-sas"
    identity            = "System"
    key_vault_secret_id = azurerm_key_vault_secret.azrmaca_sas.id
  }

  template {
    container {
      name   = "azrmaca"
      image  = "${data.azurerm_container_registry.main.login_server}/acalab/server:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "QUEUE_NAME"
        value = "tbd"
      }

      env {
        name = "QUEUE_CONNECTION"
        value = "tbd"
      }

      volume_mounts {
        name = "client-secret"
        path = "/mnt/secrets"
      }
    }

    volume {
      name         = "client-secret"
      storage_type = "Secret"
    }
  }

  ingress {
    external_enabled = true # for testing only
    target_port      = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    ip_security_restriction {
      action           = "Allow"
      ip_address_range = "85.6.236.222/32"
      name             = "Home network"
    }
  }

  depends_on = [azurerm_role_assignment.acrpull_be]
}

resource "azurerm_role_assignment" "acrpull_be" {
  scope                = data.azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.azrmaca.principal_id
}

resource "random_uuid" "fe_user_impersonation_id" {}

resource "azuread_application" "azrmaca" {
  display_name = provider::namep::namestring("azuread_application", local.namep_config, { name = "azrmaca" })
  owners       = [data.azuread_client_config.current.object_id]

  api {
    mapped_claims_enabled = true

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access example on behalf of the signed-in user."
      admin_consent_display_name = "User Impersonation"
      enabled                    = true
      id                         = random_uuid.fe_user_impersonation_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to access example on your behalf."
      user_consent_display_name  = "Access backend"
      value                      = "user_impersonation"
    }
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Admins can manage roles and perform all task actions"
    display_name         = "Admin"
    enabled              = true
    id                   = "1b19509b-32b1-4e9f-b71d-4992aa991967"
    value                = "admin"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "ReadOnly roles have limited query access"
    display_name         = "ReadOnly"
    enabled              = true
    id                   = "497406e4-012a-4267-bf18-45a1cb148a01"
    value                = "User"
  }

  feature_tags {
    enterprise = true
    gallery    = true
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
      type = "Role"
    }

    resource_access {
      id   = "b4e74841-8e56-480b-be8b-910348b18b4c" # User.ReadWrite
      type = "Scope"
    }
  }

  web {
    redirect_uris = ["https://${local.azrmaca_app_name}.${azurerm_container_app_environment.main.default_domain}/.auth/login/aad/callback"]

    implicit_grant {
      id_token_issuance_enabled = true
    }
  }

  lifecycle {
    ignore_changes = [
      # This parameter is managed by `azuread_application_identifier_uri`.
      # Details: https://github.com/hashicorp/terraform-provider-azuread/issues/428#issuecomment-1788737766
      identifier_uris,
    ]
  }
}

resource "azuread_application_identifier_uri" "azrmaca" {
  application_id = azuread_application.azrmaca.id
  identifier_uri = "api://${azuread_application.azrmaca.client_id}"
  depends_on     = [azuread_service_principal.azrmaca]
}

resource "azuread_application_password" "azrmaca" {
  application_id = azuread_application.azrmaca.id
  rotate_when_changed = {
    rotation = time_rotating.main.id
  }
}

resource "azurerm_key_vault_secret" "azrmaca_secret" {
  name         = "azrmaca-entra-app-secret"
  key_vault_id = azurerm_key_vault.main.id
  value        = azuread_application_password.azrmaca.value

  depends_on = [azurerm_role_assignment.managed_admin, azurerm_role_assignment.managed_secrets]
}

resource "azuread_service_principal" "azrmaca" {
  client_id = azuread_application.azrmaca.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azurerm_storage_container" "azrmaca_tokenstore" {
  name                  = "azrmacatokenstore"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "azrmaca_tokenstore" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_container_app.azrmaca.identity.0.principal_id
}

data "azurerm_storage_account_blob_container_sas" "azrmaca" {
  connection_string = azurerm_storage_account.main.primary_connection_string
  container_name    = azurerm_storage_container.azrmaca_tokenstore.name
  https_only        = true

  start  = time_rotating.main.id
  expiry = timeadd(time_rotating.main.id, "1440h") # 60 days

  permissions {
    read   = true
    add    = true
    create = true
    write  = true
    delete = true
    list   = true
  }
}

resource "azurerm_key_vault_secret" "azrmaca_sas" {
  name         = "azrmaca-sas"
  key_vault_id = azurerm_key_vault.main.id
  value        = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.azrmaca_tokenstore.name}${data.azurerm_storage_account_blob_container_sas.azrmaca.sas}"

  depends_on = [azurerm_role_assignment.managed_admin, azurerm_role_assignment.managed_secrets]
}

resource "time_sleep" "be_auth_delay" {
  create_duration = "90s"

  triggers = {
    container_app_id = azurerm_container_app.azrmaca.id
    key_vault_secret = azurerm_key_vault_secret.azrmaca_secret.id
  }
}

resource "azapi_resource_action" "azrmaca_auth" {
  type        = "Microsoft.App/containerApps/authConfigs@2024-03-01"
  resource_id = "${azurerm_container_app.azrmaca.id}/authConfigs/current"
  method      = "PUT"

  depends_on = [time_sleep.be_auth_delay]

  body = {
    location = azurerm_resource_group.main.location
    properties = {
      globalValidation = {
        redirectToProvider          = "azureactivedirectory"
        unauthenticatedClientAction = "RedirectToLoginPage"
      }
      identityProviders = {
        azureActiveDirectory = {
          registration = {
            clientId                = azuread_application.azrmaca.client_id
            clientSecretSettingName = "microsoft-provider-authentication-secret"
            openIdIssuer            = "https://sts.windows.net/${data.azurerm_subscription.current.tenant_id}/v2.0"
          }
          validation = {
            allowedAudiences = [
              "api://${azuread_application.azrmaca.client_id}",
            ]
            defaultAuthorizationPolicy = {
              allowedApplications = [
                azuread_application.azrmaca.client_id,
              ]
            }
          }
        }
      }
      platform = {
        enabled = true
      }

      login = {
        tokenStore = {
          azureBlobStorage = {
            sasUrlSettingName = "tokenstore-sas"
          }
          enabled = true
        }
      }
    }
  }
}