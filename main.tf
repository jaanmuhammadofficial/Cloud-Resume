terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "visitorcountjm"
    storage_account_name = "tfstatevisitorjm"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"

    tenant_id       = var.tenant_id
    subscription_id = var.subscription_id
    client_id       = var.client_id
    client_secret   = var.client_secret
  }
}

provider "azurerm" {
  features {}
}

# =====================
# Variables for backend auth
# =====================
variable "tenant_id" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}

# ===========================================================
# Resource Group
# ===========================================================
resource "azurerm_resource_group" "main" {
  name     = "visitorcountjm"
  location = "canadacentral"
}

# ===========================================================
# Storage Account for Function App
# ===========================================================
resource "azurerm_storage_account" "function_sa" {
  name                     = "visitorcountjmfuncsa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ===========================================================
# Service Plan for Linux Function App (Consumption)
# ===========================================================
resource "azurerm_service_plan" "function_plan" {
  name                = "visitorcountjm-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  kind     = "FunctionApp"
  os_type  = "Linux"
  sku_name = "Y1" # Consumption plan
}

# ===========================================================
# Azure Function App
# ===========================================================
resource "azurerm_function_app" "function" {
  name                       = "visitorcountjm"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  app_service_plan_id        = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.function_sa.name
  storage_account_access_key = azurerm_storage_account.function_sa.primary_access_key
  version                    = "~4"

  site_config {
    linux_fx_version = "Node|16" # Change to "Python|3.10" for Python
    ftps_state       = "Disabled"
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "node" # or "python"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }
}

# ===========================================================
# Cosmos DB Account
# ===========================================================
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "cosmosdbjms"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  capabilities {
    name = "EnableTable"
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }
}

# ===========================================================
# Terraform Outputs
# ===========================================================
output "function_app_default_hostname" {
  value       = azurerm_function_app.function.default_hostname
  description = "Default hostname of the Azure Function App"
}

output "function_app_url" {
  value       = "https://${azurerm_function_app.function.default_hostname}/api"
  description = "Function base URL (append route as needed)"
}

output "cosmosdb_account_endpoint" {
  value       = azurerm_cosmosdb_account.cosmos.endpoint
  description = "Cosmos DB endpoint URL"
}
