resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-web"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "web" {
  name                = "lb-web"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "bepool-web"
  loadbalancer_id = azurerm_lb.web.id
}

resource "azurerm_lb_probe" "http" {
  name            = "probe-http"
  loadbalancer_id = azurerm_lb.web.id
  protocol        = "Http"
  port            = var.server_port
  request_path    = "/"
}

resource "azurerm_lb_rule" "http" {
  name                           = "http-80"
  loadbalancer_id                = azurerm_lb.web.id
  frontend_ip_configuration_name = "public"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = var.server_port
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  probe_id                       = azurerm_lb_probe.http.id
  disable_outbound_snat          = true
}
