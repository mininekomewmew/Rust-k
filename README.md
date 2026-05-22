# HybridKore (OpenKore + Rust Core)

![Language](https://img.shields.io/badge/language-Perl%20%2B%20Rust-orange.svg)
![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)

HybridKore เป็นระบบผู้ช่วยอัตโนมัติ (Bot) สำหรับ Ragnarok Online ที่ถูกพัฒนาต่อยอดจาก OpenKore ดั้งเดิม โดยผสานการทำงานร่วมกับ **Rust** เพื่อเพิ่มประสิทธิภาพในการประมวลผลเครือข่ายและการรับส่งข้อมูล (IPC Bridge)

⚠️ **สำคัญมาก:** โปรเจกต์นี้เป็นการเปลี่ยนโครงสร้างสถาปัตยกรรมใหม่ทั้งหมด กรุณา **ลบไฟล์ OpenKore ตัวเก่าทิ้งทั้งหมด** ก่อนทำการติดตั้งตัวนี้ เพื่อป้องกันปัญหาโค้ดชนกันหรือทำงานผิดพลาด!

---

## 🛠️ สิ่งที่ต้องเตรียม (Prerequisites)

เนื่องจากระบบแกนหลักบางส่วนถูกเขียนด้วยภาษา Rust คุณจำเป็นต้องติดตั้ง Rust Compiler บน Windows ก่อนถึงจะใช้งานได้

### วิธีการติดตั้ง Rust บน Windows
1. ไปที่เว็บไซต์ทางการของ Rust: [https://rustup.rs/](https://rustup.rs/)
2. โหลดไฟล์ `rustup-init.exe` สำหรับ Windows
3. รันไฟล์ `rustup-init.exe` ที่โหลดมา
   - ระบบอาจจะแจ้งให้คุณติดตั้ง **Visual Studio C++ Build tools** ก่อน (ถ้าเครื่องยังไม่มี) ให้กดอนุญาตและติดตั้งให้เรียบร้อย
   - เมื่อหน้าจอ Command Prompt สีดำเด้งขึ้นมา ให้พิมพ์ `1` แล้วกด Enter เพื่อติดตั้งด้วยค่าเริ่มต้น (Default installation)
4. รอจนกว่าระบบจะดาวน์โหลดและติดตั้งเสร็จสิ้น (จะขึ้นข้อความว่า *Rust is installed now. Great!*)
5. ปิดหน้าจอ Command Prompt

---

## 🚀 วิธีการติดตั้งและใช้งาน (Quickstart)

1. **ทำความสะอาดบ้านเก่า:** 
   - ลบโฟลเดอร์ OpenKore ตัวเก่าของคุณทิ้งให้หมด (แนะนำให้แบ็คอัพโฟลเดอร์ `control` ของคุณไว้ที่อื่นก่อนเผื่อต้องใช้ตั้งค่าเดิม)
   
2. **ดาวน์โหลด HybridKore:**
   - โหลดโปรเจกต์นี้ลงมาที่เครื่องของคุณ หรือใช้คำสั่ง Git Clone (ต้องมี [Git](https://git-scm.com/)):
   ```bash
   git clone https://github.com/mininekomewmew/Rust-k.git
   ```

3. **คอมไพล์ระบบแกน Rust (Build):**
   - เปิด Command Prompt ขึ้นมา
   - พิมพ์คำสั่งเข้าไปในโฟลเดอร์ RustCore แล้วสั่ง Build ด้วย Cargo (ต้องรอให้โหลดเสร็จและขึ้นว่า Finished)
   ```bash
   cd src/RustCore
   cargo build --release
   cd ../..
   ```

4. **ตั้งค่าระบบ:**
   - เข้าไปตั้งค่าบอทของคุณที่โฟลเดอร์ `control` เช่นเดียวกับ OpenKore ปกติ

5. **การรันบอท (Run):**
   - รันโปรแกรมผ่าน `start.exe` หรือ `wxstart.exe` เหมือนเดิม (ระบบจะทำการเชื่อมต่อกับแกน Rust ที่คุณเพิ่ง Build เสร็จโดยอัตโนมัติ)

---

## ❓ F.A.Q. (คำถามที่พบบ่อย)

**Q: ทำไมต้องเปลี่ยนมาใช้ Rust?**
A: Rust ช่วยเพิ่มความเร็วและความปลอดภัยในการประมวลผลระดับลึก (เช่น การอ่าน Packet และ Network) ทำให้บอทสามารถทำงานได้เสถียรขึ้นและกินทรัพยากรน้อยลงในระยะยาว

**Q: ไฟล์ `control/config.txt` เดิมยังใช้ได้ไหม?**
A: ใช้ได้! แต่แนะนำให้ตรวจสอบการตั้งค่าบางตัวที่อาจเปลี่ยนไปในอัปเดตล่าสุด

**Q: รันแล้วขึ้น Error เกี่ยวกับ Rust?**
A: ตรวจสอบให้แน่ใจว่าคุณได้ติดตั้ง Rust และรีสตาร์ทคอมพิวเตอร์อย่างน้อย 1 ครั้ง เพื่อให้ Environment Variables ทำงานได้อย่างสมบูรณ์

---

## 📜 License
This software is based on OpenKore and follows the GNU General Public License, version 2.
