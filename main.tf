locals {
  name = "gnisitricksdemo"
}

resource "azurerm_resource_group" "this" {
  name     = "container-app-demo"
  location = "swedencentral"
}

# # Azure Container Registry
resource "azurerm_container_registry" "this" {
  name                = local.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Standard"
  admin_enabled       = false
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = local.name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
}

# # Container App Environment
resource "azurerm_container_app_environment" "this" {
  name                       = local.name
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.this.location
  name                = local.name
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "this" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "acrpull"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  depends_on = [
    azurerm_user_assigned_identity.this
  ]
}

# Container App
resource "azurerm_container_app" "this" {
  name                         = local.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  template {
    container {
      name   = "examplecontainer"
      image  = "${azurerm_container_registry.this.login_server}/nginx-amd:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = true
    target_port                = 80
    transport                  = "auto"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }


  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.this.id
  }
}
