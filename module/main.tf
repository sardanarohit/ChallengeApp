provider "azurerm" {
  features {}
  skip_provider_registration = "true"
}

terraform {
  backend "azurerm" {
    resource_group_name  = "RG_BASE"
    storage_account_name = "strgbase7061"
    container_name       = "tfstate"
    key                  = "func.terraform.tfstate"
  }
} 



resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.app_name}"
  location = var.loc

}

resource "azurerm_app_service_plan" "plan" {
  name                = "${var.app_name}-premiumPlan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Premium"
    size = "P1V2"
  }

}

resource "azurerm_container_registry" "registry" {
  name                = "${var.app_name}registry"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"
  admin_enabled       = true
}

output "admin_password" {
  value       = azurerm_container_registry.registry.admin_password
  description = "The object ID of the user"
}

resource "azurerm_storage_account" "storage" {
  name                     = "${var.app_name}storage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

}

resource "azurerm_function_app" "funcApp" {
  name                       = "userapi-${var.app_name}fa-${var.env_name}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
  version                    = "~2"

  app_settings = {
    FUNCTION_APP_EDIT_MODE              = "readOnly"
    https_only                          = true
    DOCKER_REGISTRY_SERVER_URL          = "${azurerm_container_registry.registry.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME     = "${azurerm_container_registry.registry.admin_username}"
    DOCKER_REGISTRY_SERVER_PASSWORD     = "${azurerm_container_registry.registry.admin_password}"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
  }

  site_config {
    always_on        = true
    linux_fx_version = "DOCKER|${azurerm_container_registry.registry.login_server}/testimage:v1.0.1"
  }
}
