terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "web-rg-final-v3"
  location = "southeastasia"
}

# 2. Network Infrastructure
resource "azurerm_virtual_network" "vnet" {
  name                = "web-vnet-final"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "web-subnet-final"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 3. Public IP & Network Interface
resource "azurerm_public_ip" "ip" {
  name                = "web-ip-final"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "web-nic-final"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip.id
  }
}

# 4. Security Group (เปิด Port 80 และ 22)
resource "azurerm_network_security_group" "nsg" {
  name                = "web-nsg-final"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 5. Virtual Machine & Automation Deployment
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "web-vm-final"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("C:/Users/pangs/.ssh/azure_rsa.pub") 
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

 custom_data = base64encode(<<-EOF
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive

    # 1. ติดตั้ง Software
    apt-get update -y
    apt-get install -y apache2 git mysql-server php libapache2-mod-php php-mysql

    # 2. Setup MySQL
    systemctl start mysql
    mysql -e "CREATE DATABASE IF NOT EXISTS sports_db;"
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password123';"
    mysql -e "FLUSH PRIVILEGES;"

    # 3. Clone Code
    rm -rf /var/www/html/*
    git clone -q https://github.com/suwimon2004/sports_rental_system1.git /var/www/html/

    # 4. Import SQL
    if [ -f "/var/www/html/sports_rental_system.sql" ]; then
        mysql -u root -ppassword123 sports_db < /var/www/html/sports_rental_system.sql
    fi

    # 5. --- ส่วนที่เพิ่มมา: แก้ไข Path รูปภาพในฐานข้อมูล (จุดตาย!) ---
    # คำสั่งนี้จะเปลี่ยน uploads\ เป็น /uploads/ และลบชื่อโฟลเดอร์ซ้ำซ้อนใน DB
    mysql -u root -ppassword123 sports_db -e "UPDATE equipment_master SET image_url = REPLACE(REPLACE(REPLACE(TRIM(image_url), '/sports_rental_system/uploads/', '/uploads/'), 'uploads\\\\', '/uploads/'), '\\\\', '/');"
    mysql -u root -ppassword123 sports_db -e "UPDATE venues SET image_url = REPLACE(REPLACE(REPLACE(TRIM(image_url), '/sports_rental_system/uploads/', '/uploads/'), 'uploads\\\\', '/uploads/'), '\\\\', '/');"

    # 6. วางไฟล์ Database Config ให้ถูกที่
    cp /var/www/html/database.php /var/www/html/customer/api/database.php
    cp /var/www/html/database.php /var/www/html/customer/database.php

    # 7. สร้าง Symbolic Links (ทางลัด)
    ln -sfn /var/www/html/uploads /var/www/html/customer/frontend/uploads
    ln -sfn /var/www/html/uploads /var/www/html/customer/api/uploads
    # สร้างโฟลเดอร์หลอกเผื่อในโค้ดเรียกหาชื่อโปรเจกต์
    ln -sfn /var/www/html /var/www/html/sports_rental_system

    # 8. ตั้งค่าสิทธิ์และ Restart
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    chmod -R 777 /var/www/html/uploads
    systemctl restart apache2
  EOF
  )
}