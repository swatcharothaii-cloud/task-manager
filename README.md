# Task Manager

ระบบจัดการงาน (Task Management) — Table / Kanban / Calendar / Gantt views
พร้อมระบบ Login แยกบัญชีผู้ใช้ (Supabase Auth) และระบบส่งอนุมัติงานให้หัวหน้า

## Setup

ฐานข้อมูลใช้ [Supabase](https://supabase.com) — รันไฟล์ `supabase_schema.sql`
ในหน้า SQL Editor ของโปรเจกต์ Supabase หนึ่งครั้งเพื่อสร้างตารางและ Row Level Security

เว็บแอปคือไฟล์ `index.html` ไฟล์เดียว (ไม่มี build step) — เปิดใช้งานผ่าน GitHub Pages ได้ทันที
