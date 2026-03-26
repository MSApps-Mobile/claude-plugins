# RTL Chat Fixer

Fixes jumbled text when mixing RTL languages (Hebrew, Arabic, Persian, Urdu) with English in Cowork and Claude Desktop chat.

## The Problem

Chat interfaces use the Unicode BiDi algorithm to render mixed-direction text. When a line contains multiple English terms inside RTL text, words get scrambled — making the response hard to read.

## What This Plugin Does

It teaches Claude how to structure mixed-direction responses so they render cleanly:

- Limits each line to one English/LTR term maximum
- Places English terms at the end of lines where possible
- Uses short paragraphs instead of long mixed-content blocks
- Wraps code and technical terms in backticks for visual clarity
- Avoids markdown lists when mixing RTL and LTR content

## Supported Languages

Hebrew, Arabic, Persian (Farsi), Urdu, Pashto, Sindhi, Kurdish (Sorani), Yiddish, Dhivehi

## Components

| Component | Description |
|-----------|-------------|
| `skills/rtl-chat` | Core formatting rules + language-specific reference material |

## Setup

No configuration needed. Install the plugin and the skill activates automatically whenever RTL text appears in the conversation.
