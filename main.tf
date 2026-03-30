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
  name     = var.resource_group_name
  location = var.location
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

# 4. Security Group
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

# 5. Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "web-vm-final"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_key_path) 
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

    # 1. ติดตั้ง Software ที่จำเป็น
    apt-get update -y
    apt-get install -y apache2 git mysql-server php libapache2-mod-php php-mysql

    # 2. ตั้งค่า MySQL (ใช้ password123 ตามที่คุณกำหนด)
    systemctl start mysql
    mysql -e "CREATE DATABASE IF NOT EXISTS sports_db;"
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'password123';"
    mysql -e "FLUSH PRIVILEGES;"

    # 3. เตรียมพื้นที่และ Clone Code จาก GitHub
    rm -rf /var/www/html/*
    git clone -q ${var.github_repo} /var/www/html/

    # 4. Import Database
    if [ -f "/var/www/html/sports_rental_system.sql" ]; then
        mysql -u root -ppassword123 sports_db < /var/www/html/sports_rental_system.sql
    fi

    # 5. แก้ไข Path รูปภาพในฐานข้อมูล (ล้างคราบ Windows ออกให้หมด)
    mysql -u root -ppassword123 sports_db -e "UPDATE equipment_master SET image_url = REPLACE(REPLACE(REPLACE(TRIM(image_url), '/sports_rental_system/uploads/', '/uploads/'), 'uploads\\\\', '/uploads/'), '\\\\', '/');"
    mysql -u root -ppassword123 sports_db -e "UPDATE venues SET image_url = REPLACE(REPLACE(REPLACE(TRIM(image_url), '/sports_rental_system/uploads/', '/uploads/'), 'uploads\\\\', '/uploads/'), '\\\\', '/');"

    # 6. สร้างไฟล์ database.php ใหม่ (เพื่อแก้ปัญหา "กำลังโหลดสนาม...")
    # วิธีนี้จะทำให้ PHP เชื่อมต่อฐานข้อมูลได้ 100% ไม่ว่าไฟล์เดิมใน Git จะเขียนไว้อย่างไร
    cat <<DB_CONFIG > /var/www/html/database.php
<?php
\$host = 'localhost';
\$user = 'root';
\$pass = 'password123';
\$db   = 'sports_db';
\$conn = new mysqli(\$host, \$user, \$pass, \$db);
if (\$conn->connect_error) { die("Connection failed: " . \$conn->connect_error); }
\$conn->set_charset("utf8mb4");
?>
DB_CONFIG

    # ก๊อปปี้ไปวางในทุกโฟลเดอร์ที่มีระบบย่อย
    for d in customer staff executive admin warehouse rector; do
      if [ -d "/var/www/html/\$d" ]; then
        cp /var/www/html/database.php "/var/www/html/\$d/database.php"
        # หากมีโฟลเดอร์ api ย่อยๆ ก็วางดักไว้ด้วย
        [ -d "/var/www/html/\$d/api" ] && cp /var/www/html/database.php "/var/www/html/\$d/api/database.php"
      fi
    done

    # 7. แก้ไข Path ในไฟล์โค้ด (ท่าไม้ตาย: เปลี่ยน Path ในไฟล์ .php และ .js โดยตรง)
    # ป้องกันกรณีโค้ดมีการเรียก /sports_rental_system/ แบบ Hard-coded
    find /var/www/html -type f \( -name "*.php" -o -name "*.js" -o -name "*.html" \) \
    -exec sed -i 's|/sports_rental_system/uploads/|/uploads/|g' {} + \
    -exec sed -i 's|sports_rental_system/uploads/|/uploads/|g' {} + \
    -exec sed -i 's|/sports_rental_system/|/|g' {} +

    # 8. สร้าง Symbolic Links สำหรับ API และ Uploads (ดักทุกทาง)
    # เพื่อให้หน้า "จองสนาม" และ "สาขา" โหลดขึ้น
    for d in customer staff executive admin warehouse rector; do
      if [ -d "/var/www/html/\$d/backend/api" ]; then
        ln -sfn "/var/www/html/\$d/backend/api" "/var/www/html/\$d/api"
      fi
      # สร้างทางลัดรูปภาพในทุกแผนก
      ln -sfn /var/www/html/uploads "/var/www/html/\$d/uploads"
    done

    # ทำ Link ตัวหลักกลับมาที่ชื่อโปรเจกต์เดิมเผื่อบางไฟล์เรียกหา
    ln -sfn /var/www/html /var/www/html/sports_rental_system

    # 9. ตั้งค่าสิทธิ์ (Permissions) และ Restart Service
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    chmod -R 777 /var/www/html/uploads
    systemctl restart apache2
  EOF
  )
}