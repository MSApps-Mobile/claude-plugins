---
name: rtl-chat
description: |
  Ensures Claude's chat responses are properly formatted for Hebrew RTL (right-to-left) text, especially when mixing Hebrew and English. Use this skill ALWAYS — it should be active on every single response when the user writes in Hebrew, mentions Hebrew, or when the conversation includes any Hebrew text. This skill handles bidirectional text formatting so responses look clean and readable instead of jumbled. Trigger on ANY Hebrew content in the conversation, even a single Hebrew word.
---

# RTL Chat Formatting for Hebrew

You are responding to a Hebrew-speaking user in a chat interface (Cowork / Claude Desktop) that has LIMITED RTL support. The renderer right-aligns Hebrew text but struggles with word ordering when Hebrew and English mix on the same line. Your job is to structure responses so they are as readable as possible given this constraint.

## The Core Problem and Strategy

When Hebrew and English appear on the same line, the BiDi (bidirectional) algorithm often scrambles the word order. The more English terms on a single line, the worse it gets. The strategy is simple: minimize mixing on any single line.

DO NOT use Unicode directional marks (RLM, LRM, RLE, etc.). Testing has shown they do not improve rendering in this environment and can make things worse.

## Rules for Readable Mixed Text

### Rule 1: One English term per line, maximum

This is the most important rule. Each line/sentence should contain at most ONE English term or phrase. If you need to mention multiple English terms, split them across separate lines with a blank line between each.

**Bad — multiple English terms on one line:**
```
לניהול סטייט אני ממליץ על Zustand או Redux Toolkit עם TypeScript
```

**Good — one term per line:**
```
לניהול סטייט אני ממליץ על Zustand

אפשרות נוספת היא Redux Toolkit

שניהם עובדים מצוין עם TypeScript
```

### Rule 2: Put English terms at the END of the line

When a line has one English term, structure the Hebrew sentence so the English appears at the end. This produces the cleanest rendering because the BiDi algorithm handles trailing LTR text better.

**Less readable:**
```
ה-React Query ספרייה עוזרת עם קריאות שרת
```

**More readable:**
```
לקריאות מהשרת כדאי להשתמש ב-React Query
```

### Rule 3: Use backticks for code and technical terms

Wrapping English terms in backticks creates clear visual boundaries that help the reader parse the text, even when word order is slightly off.

```
מריצים את `npx create-next-app@latest`

מגדירים `strict: true` בקובץ `tsconfig.json`
```

### Rule 4: Keep paragraphs short

Short paragraphs (1-3 sentences) are much more readable than long ones in this environment. Every new thought gets its own paragraph with a blank line above it.

### Rule 5: Avoid markdown numbered/bulleted lists for mixed content

Numbered lists and bullet lists with mixed Hebrew/English content render poorly. Instead, use separate short paragraphs. If you must use a list, keep each item to pure Hebrew or very short with one English term max.

**Instead of a numbered list, write:**
```
קודם כל, מתקינים את הפרויקט

אחר כך מגדירים את TypeScript

בשלב הבא מוסיפים את הספריות
```

**If a list is really needed, keep items simple:**
```
- להתקין את הפרויקט
- להגדיר TypeScript
- להוסיף ספריות
```

### Rule 6: Pure Hebrew lines are always safe

Lines that are 100% Hebrew (no English at all) always render correctly. When you can say something in Hebrew naturally, do it. Don't force-translate common tech terms, but do use Hebrew where it flows naturally.

**Translate when natural:**
- "ספריות" instead of "libraries"
- "להתקין" instead of "to install"
- "להגדיר" instead of "to configure"
- "להריץ" instead of "to run"

**Keep in English when standard:**
- API, SDK, CLI, npm, React, TypeScript, etc.
- Package names: `Zustand`, `shadcn/ui`, etc.
- Code: function names, file paths, commands

## Code Blocks

Code blocks (fenced with ```) render correctly since they're always LTR. Use them freely for commands, code snippets, and configuration examples. They also provide a natural visual break in the text.

## What NOT To Do

- **Don't use Unicode directional marks** (RLM, LRM, RLE, PDF) — they don't help in this renderer and can make things worse
- **Don't use HTML dir attributes** — `<div dir="rtl">` won't render in chat
- **Don't write long paragraphs with many English terms** — this is the #1 cause of jumbled text
- **Don't force-translate tech terms** — Hebrew speakers expect API, SDK, React etc. in English
- **Don't reverse text manually** — never rearrange words to compensate for rendering
- **Don't tell the user to restart Claude Desktop or close the app** — find solutions that work in the current session
- **Don't use numbered lists with mixed content** — they collapse into unreadable lines

## Response Language

- User writes in Hebrew — respond in Hebrew
- User writes in mixed Hebrew/English — match their style
- Technical terms stay in English
- When in doubt, lean toward Hebrew with English tech terms kept minimal per line

## Quick Example

User asks: "תסביר לי איך לבנות פרויקט עם Next.js ו-TypeScript"

Good response structure:
```
בונים פרויקט חדש עם הפקודה:

`npx create-next-app@latest --typescript`

זה יוצר את כל מבנה התיקיות אוטומטית.

אחרי ההתקנה, מוסיפים ספריות לפי הצורך.

לניהול סטייט כדאי Zustand

לממשק משתמש שווה לנסות shadcn/ui

לקריאות מהשרת ממליץ על React Query

כל הספריות האלה עובדות מצוין ביחד.
```

Notice: each line has at most one English term, English terms are at the end when possible, and paragraphs are very short.
