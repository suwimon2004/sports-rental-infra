output "public_ip_address" {
  description = "IP ของเครื่อง Server"
  value       = azurerm_public_ip.ip.ip_address
}

output "how_to_access" {
  description = "ลิ้งก์สำหรับเข้าใช้งานเว็บไซต์"
  value       = "http://${azurerm_public_ip.ip.ip_address}/customer/frontend/index.html"
}