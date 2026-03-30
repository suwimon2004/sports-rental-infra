# Infrastructure for Sports Rental System (Azure)

โปรเจกต์นี้ใช้ Terraform ในการสร้าง Infrastructure บน Azure และ Deploy ระบบจองอุปกรณ์กีฬาอัตโนมัติ

## รายละเอียดโปรเจกต์
- **Provisioning:** สร้าง VM (Ubuntu 22.04), VNet, NSG (เปิด Port 80, 22)
- **Deployment:** ติดตั้ง Apache, PHP, MySQL และดึง Code จาก GitHub มา Deploy อัตโนมัติ
- **Fix Path:** มีการจัดการ Symbolic Link และ SQL Update เพื่อแก้ปัญหาการแสดงผลรูปภาพบน Linux

## ขั้นตอนการรัน (สำหรับอาจารย์)
1. ติดตั้ง Azure CLI และสั่ง `az login`
2. ตรวจสอบ SSH Public Key ในเครื่อง (ไฟล์นี้ใช้ Path: `C:/Users/pangs/.ssh/azure_rsa.pub`)
3. สั่งรันคำสั่ง:
   ```powershell
   terraform init
   terraform apply -auto-approve
   terraform destroy -auto-approve
---
