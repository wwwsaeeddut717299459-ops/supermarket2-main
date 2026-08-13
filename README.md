# supermarket

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## تعديلات الذمم
- الموردون: الرصيد المعروض هو «في ذمتي للموردين».
- العملاء: يظهر إجمالي المبالغ المتبقية عند العملاء.
- العملاء: يوجد سقف مديونية، والصفر يعني بدون سقف.
- البيع الآجل يمنع تجاوز السقف المحدد للعميل.
- قاعدة البيانات الجديدة تستخدم ملف `supermarket_fresh.db` حتى يبدأ التطبيق بقاعدة جديدة مستقلة عن `supermarket.db`.
- بعد تعديل جدول العملاء يجب تشغيل `dart run build_runner build --delete-conflicting-outputs` لتوليد ملفات Drift.
