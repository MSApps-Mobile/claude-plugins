---
name: rtl-chat
description: |
  Ensures Claude's chat responses are properly formatted for RTL (right-to-left) text in Hebrew, Arabic, Persian (Farsi), Urdu, and other RTL languages — especially when mixing with English or other LTR text. Use this skill ALWAYS — it should be active on every single response when the user writes in any RTL language, mentions an RTL language, or when the conversation includes any RTL script. This skill handles bidirectional text formatting so responses look clean and readable instead of jumbled. Trigger on ANY RTL content in the conversation, even a single word in Hebrew, Arabic, Persian, or Urdu script.
---

# RTL Chat Formatting

You are responding to a user who writes in an RTL (right-to-left) language in a chat interface (Cowork / Claude Desktop) that has LIMITED RTL support. The renderer right-aligns RTL text but struggles with word ordering when RTL and LTR scripts mix on the same line. Structure responses so they are as readable as possible given this constraint.

## Supported RTL Languages

This skill applies when the user writes in any of these languages/scripts:

Hebrew (עברית), Arabic (العربية), Persian/Farsi (فارسی), Urdu (اردو), Pashto (پښتو), Sindhi (سنڌي), Kurdish (Sorani: کوردی), Yiddish (ייִדיש), Dhivehi/Maldivian (ދިވެހި)

Detect the language from the user's input and respond in the same language. All formatting rules below apply equally to every RTL language.

## The Core Problem and Strategy

When RTL and LTR text appear on the same line, the BiDi (bidirectional) algorithm often scrambles the word order. The more LTR terms on a single line, the worse it gets. The strategy: **minimize mixing on any single line.**

DO NOT use Unicode directional marks (RLM, LRM, RLE, etc.). They do not improve rendering in this environment and can make things worse.

## Rules for Readable Mixed Text

### Rule 1: One LTR term per line, maximum

The most important rule. Each line should contain at most ONE English/LTR term or phrase. If multiple LTR terms are needed, split them across separate lines with a blank line between each.

Bad — multiple LTR terms on one line:

```
לניהול סטייט אני ממליץ על Zustand או Redux Toolkit עם TypeScript
```

```
لإدارة الحالة أنصح باستخدام Zustand أو Redux Toolkit مع TypeScript
```

Good — one term per line:

```
לניהול סטייט אני ממליץ על Zustand

אפשרות נוספת היא Redux Toolkit

שניהם עובדים מצוין עם TypeScript
```

```
لإدارة الحالة أنصح باستخدام Zustand

خيار آخر هو Redux Toolkit

كلاهما يعمل بشكل ممتاز مع TypeScript
```

### Rule 2: Put LTR terms at the END of the line

Structure the RTL sentence so the English/LTR term appears at the end. The BiDi algorithm handles trailing LTR text better.

Less readable:

```
ה-React Query ספרייה עוזרת עם קריאות שרת
```

More readable:

```
לקריאות מהשרת כדאי להשתמש ב-React Query
```

### Rule 3: Use backticks for code and technical terms

Wrapping LTR terms in backticks creates clear visual boundaries that help the reader parse the text, even when word order is slightly off.

```
מריצים את `npx create-next-app@latest`

نشغّل الأمر `npx create-next-app@latest`
```

### Rule 4: Keep paragraphs short

Short paragraphs (1-3 sentences) are much more readable than long ones. Every new thought gets its own paragraph with a blank line above it.

### Rule 5: Avoid markdown lists for mixed content

Numbered lists and bullet lists with mixed RTL/LTR content render poorly. Use separate short paragraphs instead. If a list is truly needed, keep each item to pure RTL text or very short with one LTR term max.

Instead of a numbered list, write separate paragraphs:

```
קודם כל, מתקינים את הפרויקט

אחר כך מגדירים את TypeScript

בשלב הבא מוסיפים את הספריות
```

```
أولاً، نثبّت المشروع

بعد ذلك نضبط TypeScript

في الخطوة التالية نضيف المكتبات
```

If a list is really needed, keep items simple:

```
- להתקין את הפרויקט
- להגדיר TypeScript
- להוסיף ספריות
```

### Rule 6: Pure RTL lines are always safe

Lines that are 100% RTL (no LTR at all) always render correctly. Use the native language where it flows naturally. Don't force-translate standard tech terms, but do use RTL words where natural.

Translate when natural (Hebrew examples):

"ספריות" instead of "libraries", "להתקין" instead of "to install", "להגדיר" instead of "to configure", "להריץ" instead of "to run"

Translate when natural (Arabic examples):

"مكتبات" instead of "libraries", "تثبيت" instead of "install", "إعداد" instead of "configure", "تشغيل" instead of "run"

Keep in English when standard across all languages:

API, SDK, CLI, npm, React, TypeScript, Python, etc. Package names, function names, file paths, commands.

### Rule 7: Brackets around an LTR term are a hidden jumble source

Parentheses, square brackets, and quotation marks placed directly around an English term inside an RTL line are one of the most common causes of "the punctuation moved" complaints. The bracket belongs to the LTR run, so the renderer often pushes the closing bracket — or both — to the wrong side of the line.

Less readable:

```
מומלץ לעבוד עם הגרסה האחרונה (React 18) בפרויקט
```

More readable — lift the parenthetical onto its own line, or drop the brackets entirely:

```
מומלץ לעבוד עם הגרסה האחרונה של React

הכוונה לגרסה 18
```

The same goes for a label ending in a colon right before an LTR term: put the command or term on the next line so the colon stays attached to the RTL text.

### Rule 8: Don't use tables for mixed-direction content

Markdown tables are the worst case for the BiDi algorithm. Each cell is its own tiny direction context, the column alignment fights the RTL reading order, and the header row can flip independently of the body rows. A table that mixes Hebrew or Arabic with English collapses into something genuinely unreadable.

Present structured data as short labelled paragraphs instead:

```
ספרייה: React
תפקיד: ניהול ממשק המשתמש

ספרייה: Zustand
תפקיד: ניהול הסטייט
```

A table is fine only when every cell is pure RTL, or every cell is pure LTR (for example a table of `npm` commands) — never a mix.

## Code Blocks

Code blocks (fenced with ```) render correctly since they are always LTR. Use them freely for commands, code snippets, and configuration examples. They also provide a natural visual break in the text.

## Headings

A heading that mixes RTL and LTR scripts jumbles exactly like body text — and because headings are visually prominent, a broken one stands out more. Keep headings short and, where possible, pure RTL. If a heading needs an English term, prefer moving it into the paragraph below and leaving the heading itself in the RTL language.

## Cowork and agent-mode situations

In Cowork and other agent/desktop modes, replies to RTL-language users tend to be unusually LTR-dense: file paths, branch names, PR numbers, shell commands, git output, and progress summaries. That is precisely the content that jumbles worst, so it needs deliberate handling.

Status and progress lines: keep each update on its own line, and keep that line either fully RTL or fully LTR. A line carrying one backticked path reads fine; a line like "עדכנתי את cookies.js, schema.js ו-config.js" stacks three LTR terms — split it across three lines.

File paths, URLs, branch names, and PR references: always wrap them in backticks, and count each as one LTR term for the one-per-line rule. Better still, put the path on its own line beneath a short RTL label.

Final summaries and reports: don't assemble them as one long bullet list of mixed-direction lines — that is the single worst pattern. Use short RTL paragraphs, and isolate every command or path in a fenced code block.

Quoted terminal or command output: always place it in a fenced code block. It is pure LTR, and the block stops it from contaminating the surrounding RTL text.

Good — a status update written for clean rendering:

```
סיימתי את העדכון של הסקיל

הקובץ ששונה:
plugins/rtl-chat-fixer/skills/rtl-chat/SKILL.md

השינוי נדחף לענף main
```

## What NOT To Do

- Do not use Unicode directional marks (RLM, LRM, RLE, PDF) — they don't help and can make things worse
- Do not use HTML dir attributes — `<div dir="rtl">` won't render in chat
- Do not write long paragraphs with many LTR terms — this is the #1 cause of jumbled text
- Do not force-translate tech terms — RTL-language speakers expect API, SDK, React etc. in English
- Do not reverse text manually — never rearrange words to compensate for rendering
- Do not use numbered lists with mixed content — they collapse into unreadable lines
- Do not put mixed-direction data in markdown tables — they are the worst BiDi case (see Rule 8)
- Do not wrap English terms in parentheses or brackets inside an RTL line — the brackets flip (see Rule 7)

## Response Language

- User writes in an RTL language — respond in that same language
- User writes in mixed RTL/LTR — match their style
- Technical terms stay in English
- When in doubt, lean toward the RTL language with English tech terms kept minimal per line

For detailed language-specific guidance (Hebrew, Arabic, Persian, Urdu), read `references/language-specifics.md`.
