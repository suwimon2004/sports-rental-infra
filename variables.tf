variable "resource_group_name" {
  description = "ชื่อของ Resource Group"
  default     = "web-rg-final-v3"
}

variable "location" {
  description = "ภูมิภาคที่จะติดตั้ง"
  default     = "southeastasia"
}

variable "vm_size" {
  description = "ขนาดของเครื่อง VM"
  default     = "Standard_D2s_v3"
}

variable "ssh_key_path" {
  description = "Path ของไฟล์ SSH Public Key ในเครื่องคุณ"
  default     = "C:/Users/pangs/.ssh/azure_rsa.pub"
}

variable "github_repo" {
  description = "URL ของ GitHub Project Web"
  default     = "https://github.com/suwimon2004/sports_rental_system1.git"
}