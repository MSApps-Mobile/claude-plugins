# Language-Specific RTL Guidance

## Hebrew (עברית)

Hebrew is written right-to-left. Technical culture uses many English loan words (e.g., "באג" for bug, "קוד" for code) alongside pure English terms.

Common natural Hebrew translations to prefer over English:

| Use Hebrew        | Instead of English |
| ----------------- | ------------------ |
| ספריות            | libraries          |
| להתקין            | to install         |
| להגדיר            | to configure       |
| להריץ             | to run             |
| קובץ              | file               |
| תיקייה            | folder/directory   |
| מסד נתונים        | database           |
| שרת               | server             |
| לקוח              | client             |

Keep in English: API, SDK, CLI, npm, yarn, React, TypeScript, Python, Node.js, Git, Docker, and all package/library names.

The prefix ב- (be-) is commonly attached directly to English terms: ב-React, ב-TypeScript. This is fine — just make sure only one such term appears per line.

## Arabic (العربية)

Arabic is written right-to-left with connected script. The BiDi issues are the same as Hebrew. Arabic technical writing often uses English terms directly.

Common natural Arabic translations to prefer:

| Use Arabic   | Instead of English |
| ------------ | ------------------ |
| مكتبات       | libraries          |
| تثبيت        | install            |
| إعداد        | configure          |
| تشغيل        | run                |
| ملف          | file               |
| مجلد         | folder/directory   |
| قاعدة بيانات | database           |
| خادم         | server             |
| عميل         | client             |

Note: Arabic has many regional dialects (Egyptian, Gulf, Levantine, Maghreb). Match the user's dialect if identifiable from their writing. If unclear, use Modern Standard Arabic (فصحى).

Arabic uses different connectors than Hebrew. The preposition في (in/with) is a separate word, not a prefix — so "في React" stays as two words.

## Persian / Farsi (فارسی)

Persian uses the Arabic script but is a different language. Persian technical writing mixes in English terms similarly to Hebrew and Arabic.

Common natural Persian translations:

| Use Persian     | Instead of English |
| --------------- | ------------------ |
| کتابخانه‌ها      | libraries          |
| نصب کردن        | install            |
| پیکربندی        | configure          |
| اجرا کردن       | run                |
| فایل            | file               |
| پوشه            | folder/directory   |
| پایگاه داده     | database           |
| سرور            | server             |

Persian uses a half-space (zero-width non-joiner) between compound words. This is fine — it does not affect BiDi rendering.

Persian connects prepositions similarly to Arabic: "با React" (with React), "در TypeScript" (in TypeScript).

## Urdu (اردو)

Urdu uses the Nastaliq variant of Arabic script and is written right-to-left. Technical Urdu writing frequently borrows English terms.

Common natural Urdu translations:

| Use Urdu      | Instead of English |
| ------------- | ------------------ |
| لائبریریاں    | libraries          |
| انسٹال کرنا   | install            |
| ترتیب دینا    | configure          |
| چلانا         | run                |
| فائل          | file               |
| فولڈر         | folder             |
| ڈیٹابیس      | database           |
| سرور          | server             |

Urdu has more Perso-Arabic vocabulary than Arabic itself. Match formality level to the user's writing style.

## General Tips for All RTL Languages

1. **Detect language from user input** — respond in whatever language the user writes in
2. **Don't mix RTL languages** — if the user writes Hebrew, don't include Arabic examples and vice versa
3. **Numbers are LTR in all RTL languages** — numbers like 2024, port 3000, version 1.2.3 render LTR within RTL text, which is correct behavior
4. **Punctuation follows the language** — Hebrew/Arabic question marks, commas, and periods should be used when writing in those languages
5. **URLs and paths are always LTR** — file paths, URLs, and email addresses are LTR content and count as LTR terms for the "one per line" rule
