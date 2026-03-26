---
name: opsagent-outreach
description: שליחת הודעות LinkedIn ואימייל outreach יומיות עבור OpsAgent — מוצא פרוספקטים בשווקים בינלאומיים (דובאי, ארה"ב, בריטניה, אירופה, אוסטרליה), כותב הודעות מותאמות באנגלית, שולח בלינקדאין דרך Chrome ובאימייל דרך Zoho Mail, מעדכן Notion, ושולח דוח סיכום. השתמש ב-Skill הזה בכל פעם שמיכל מבקשת outreach ל-OpsAgent, שליחת הודעות ללידים של OpsAgent, פרוספקטינג בינלאומי, או כל בקשה שקשורה לקידום מכירות של OpsAgent. גם אם מיכל אומרת "תשלח הודעות ל-OpsAgent" או "outreach לOpsAgent" או "תמצא לידים ל-OpsAgent" — זה ה-Skill הנכון.
---

## מה המשימה הזו עושה — חובה לקרוא לפני הכל

המשימה היא **לשלוח הודעות בפועל ב-LinkedIn ובאימייל** עבור **OpsAgent** — לא רק לכתוב אותן.
הסדר: Notion → Apollo (חיפוש + העשרה) → LinkedIn Scraper (מחקר פרופילים) → כתיבה → **שליחה ב-LinkedIn + Email (חובה!)** → שמירה ב-Apollo → עדכון Notion → מייל סיכום.

**אם לא שלחת את ההודעות בפועל — המשימה לא הושלמה.**

---

## רקע — מהו OpsAgent

OpsAgent הוא מוצר AI שמחליף את ה-back-office של עסקי שירות עם סוכני AI אוטונומיים.

**מה המוצר עושה:**
- מאפשר אוטומציה של 18 מחלקות תפעוליות: ניהול לידים, מכירות, גיוס, פיננסים, תוכן, פרויקטים, ועוד
- רץ בפועל על חברה אמיתית (MSApps — 40+ עובדים, 15+ שנים)
- 96% gross margin על תפעול
- 50+ אינטגרציות (Slack, Monday, Gmail, Calendar, Notion, LinkedIn, Toggl)
- עולה לאוויר תוך ימים, לא חודשים

**תמחור:**
- Setup: $1,500 חד-פעמי
- Starter: $2,200/חודש (עד 5 אנשים, 2 מחלקות)
- Growth: $4,400/חודש (6-20 אנשים, כל 18 המחלקות)
- Enterprise: Custom

**קהל יעד:**
- עסקי שירות עם 10-50 עובדים
- סוכנויות דיגיטל, חברות IT, consultancies, סוכנויות שיווק, staffing
- CEO/Founder/COO/CTO שטובע בתפעול

**יתרון תחרותי:**
- לא תיאוריה — רץ בפרודקשן על חברה אמיתית
- 18 מחלקות (המתחרה Every.io מכסה רק Finance + HR)
- מחיר נמוך מ-ops hire ($60-80K/year) וממשרד אוטומציה ($2K-8K/month retainer)

**אתר:** https://opsagent.netlify.app
**LinkedIn page:** https://www.linkedin.com/company/112508707/

---

## הוראות הרצה — חשוב מאוד!

**אין לשאול את מיכל כלום. יש לפעול באופן מלא אוטומטי בכל הרצה.**

---

## שלב 1 — Notion: קרא יומן שליחות ותבניות

פתח את Notion וקרא את הדף:
- URL: https://www.notion.so/32e38b5dfb278153b9d4d5379a8b4fc9
- קרא את Part 4 (תבניות), Part 6 (יומן שליחות — מי כבר קיבל הודעה)

---

## שלב 2 — בחר שוק וסגמנט

בחר שוק יעד לפי סדר עדיפות מתחלף:
1. Dubai / UAE — סטארטאפים, סוכנויות דיגיטל, חברות טק ב-DIFC
2. United States — digital agencies, IT consultancies, marketing agencies (Austin, Miami, NYC, SF, Denver)
3. United Kingdom — agencies, consultancies (London, Manchester)
4. Germany — tech companies, Mittelstand (Berlin, Munich)
5. Netherlands — startups, agencies (Amsterdam)
6. Australia — agencies, tech companies (Sydney, Melbourne)

**כלל:** סובב בין השווקים. אל תשלח לאותו שוק יומיים ברצף (אלא אם יש פחות מ-3 שווקים מכוסים).

זהה סגמנט ספציפי בתוך השוק (למשל: "Dubai digital agencies", "Austin SaaS startups", "London marketing agencies").

---

## שלב 3 — מצא 5-10 פרוספקטים חדשים באמצעות Apollo + LinkedIn Scraper

### 3A — חפש חברות ב-Apollo

השתמש ב-`mcp__8df4e691-d022-435a-b7c8-100b71c89b2d__apollo_mixed_companies_search` עם:
- `q_organization_keyword_tags`: מילות מפתח לסגמנט (לדוגמה: `["digital agency", "IT consulting", "marketing agency"]`)
- `organization_num_employees_ranges`: `["11,50"]` (טווח 10-50 עובדים)
- `organization_locations`: לפי השוק שנבחר (לדוגמה: `["Dubai, United Arab Emirates"]`)
- `per_page`: 25

### 3B — מצא מקבלי החלטות ב-Apollo

השתמש ב-`mcp__8df4e691-d022-435a-b7c8-100b71c89b2d__apollo_mixed_people_api_search` עם:
- `person_titles`: `["CEO", "Founder", "COO", "CTO", "Managing Director", "Owner"]`
- `person_seniorities`: `["c_suite", "founder"]`
- `q_organization_keyword_tags`: אותן מילות מפתח מ-3A
- `organization_num_employees_ranges`: `["11,50"]`
- `organization_locations` או `person_locations`: לפי השוק שנבחר
- `per_page`: 15

### 3C — העשר את הלידים (אימיילים + טלפונים)

השתמש ב-`mcp__8df4e691-d022-435a-b7c8-100b71c89b2d__apollo_people_match` לכל ליד עם:
- `first_name`, `last_name`, `domain`
- `reveal_personal_emails`: `true`

לחלופין, אם יש 10 לידים ומעלה — השתמש ב-`apollo_people_bulk_match` לחיסכון בקריאות.

**חשוב:** וודא שהלידים לא מופיעים כבר ביומן השליחות ב-Notion (Part 6).

### 3D — מחקר פרופילי LinkedIn דרך LinkedIn Scraper

לכל ליד שנבחר, השתמש ב-LinkedIn Scraper MCP לקריאת נתוני פרופיל:
- `search_people` — לחיפוש אנשים לפי שם + חברה + מיקום
- `get_person_profile` — לקריאת פרופיל מלא (sections: experience, posts) כדי למצוא פרט אישי להודעה

**יתרון:** LinkedIn Scraper מחזיר נתונים מובנים ב-5-10x פחות טוקנים מגלישה ב-Chrome.

**Fallback:** אם LinkedIn Scraper לא זמין או מחזיר שגיאה — חפש ב-Chrome (`mcp__Claude_in_Chrome__navigate` → `mcp__Claude_in_Chrome__get_page_text`).

**סימנים מזהים לפרוספקט טוב:**
- החברה גדלה (גיוס, לקוחות חדשים, hiring)
- הם מחפשים ops manager / office manager (= צורך באוטומציה)
- משתמשים בהרבה כלי SaaS
- הפאונדר עדיין עושה ops בעצמו

---

## שלב 4 — כתוב הודעות מותאמות אישית

- בחר את התבנית המתאימה מ-Part 4 ב-Notion
- שלב פרט ספציפי אחד על החברה/האדם (מ-Apollo enrichment או מהפרופיל ב-LinkedIn Scraper)
- הודעה קצרה: 3-5 משפטים
- פתיחה אישית, לא גנרית
- CTA רך ("happy to show you", "worth a quick chat")
- סגנון founder-to-founder

### חוקי ברזל — שפה וסגנון!

**1. כל ההודעות באנגלית מלאה.** קהל היעד הוא בינלאומי — דובאי, ארה"ב, אירופה, אוסטרליה.

**2. מיכל שץ היא אישה.** בכל הקשר שצריך — "I'm Michal, founder of OpsAgent". לא צריך gender-specific language באנגלית, אבל אם יש חתימה — Michal Shatz, Founder.

**3. לא להגזים.** אל תכתוב "revolutionary" או "game-changing". תן עובדות: "18 departments automated", "runs our own company's operations", "96% gross margin".

**4. LinkedIn Connect Note = מקסימום 300 תווים.** אם ההודעה ארוכה — שלח גרסה מקוצרת כ-Note, ואת המלאה אחרי שהחיבור מתקבל.

**5. ⭐ חובה לכלול לינק בכל הודעה:** https://opsagent.netlify.app — תמיד, ללא יוצא מן הכלל. שלב אותו טבעי (למשל: "worth a look: https://opsagent.netlify.app"). גם ב-300 תווים — הלינק חייב להיות שם.

---

## שלב 5 — שלח את ההודעות

### LinkedIn (חובה — שליחה דרך Chrome):
1. היכנס ל-LinkedIn דרך Chrome (`mcp__Claude_in_Chrome__navigate`)
2. חפש את הפרופיל לפי שם + חברה
3. אם עוד לא מחוברים — לחץ **Connect** → **Add a note** → הדבק את ההודעה
4. אם כבר מחוברים — לחץ **Message** → הדבק ושלח

**הערה:** השתמש ב-LinkedIn Scraper רק למחקר. השליחה עצמה חייבת להיות דרך Chrome.

### Email (בנוסף ל-LinkedIn):
אם יש לך אימייל של הפרוספקט (מ-Apollo enrichment):
- שלח cold email דרך **Zoho Mail MCP**
- השתמש ב-`mcp__zoho-mail__zohomail_send_message` עם `fromAddress: "michal@msapps.mobi"`
- Subject line קצר וספציפי
- גוף המייל מבוסס על Template C מ-Notion

**לא לעבור לשלב 6 לפני ששלחת לכל הפרוספקטים ברשימה.**

---

## שלב 6 — שמור לידים ב-Apollo

לכל פרוספקט שנשלחה לו הודעה, צור contact ב-Apollo:

השתמש ב-`mcp__8df4e691-d022-435a-b7c8-100b71c89b2d__apollo_contacts_create` עם:
- `first_name`, `last_name`, `email`, `title`, `organization_name`
- `direct_phone` או `mobile_phone` (אם זמין מההעשרה)
- `label_names`: `["OpsAgent Outreach"]`
- `run_dedupe`: `true`

**אופציונלי — טעינה לסיקוונס:**
אם קיים סיקוונס OpsAgent ב-Apollo, השתמש ב-`apollo_emailer_campaigns_search` כדי למצוא אותו, ואז ב-`apollo_emailer_campaigns_add_contact_ids` כדי להוסיף את הלידים לסיקוונס לפולואפ אוטומטי.

---

## שלב 7 — עדכן את Notion

עדכן את יומן השליחות (Part 6) בדף:
- URL: https://www.notion.so/32e38b5dfb278153b9d4d5379a8b4fc9

הוסף לכל פרוספקט:
- תאריך שליחה = היום
- שם + חברה + תפקיד + שוק
- ערוץ (LinkedIn / Email / Both)
- תבנית שנבחרה
- סטטוס = Pending
- תאריך follow-up = +7 ימים מהיום
- Apollo Contact ID (אם נשמר)

---

## שלב 8 — שלח מייל סיכום

שלח ל-michal@msapps.mobi עם:
- כמה הודעות נשלחו
- לאיזה שוק וסגמנט
- רשימת הפרוספקטים (שם, חברה, תפקיד, ערוץ, אימייל מ-Apollo)
- ההודעות עצמן
- תגובות שהתקבלו (אם יש)
- כמה לידים נשמרו ב-Apollo

**שיטת שליחה — Zoho Mail MCP:**
השתמש ב-`mcp__zoho-mail__zohomail_send_message` עם `fromAddress: "michal@msapps.mobi"`

**חלופה (אם Zoho MCP לא זמין)** — שלח דרך Gmail ב-Chrome.

---

## שלב 9 — בדוק תגובות ב-LinkedIn

היכנס לדפדפן (Chrome), פתח LinkedIn ובדוק הודעות נכנסות:
- האם מישהו מהפרוספקטים של OpsAgent חזר עם תגובה
- **חשוב:** התעלם משיחות גיוס ומשיחות MSApps B2B — רק תגובות OpsAgent
- דווח למיכל במייל הסיכום על כל תגובה שהתקבלה

---

## שלב 10 — Follow-ups

בדוק ב-Notion אם יש פרוספקטים שעבר שבוע מאז השליחה וסטטוס = Pending:
- שלח follow-up (Template D) ב-LinkedIn או באימייל
- עדכן את הסטטוס ב-Notion ל-Follow-up Sent
- עדכן תאריך follow-up הבא = +7 ימים

אם פרוספקט לא הגיב אחרי 2 follow-ups (21 ימים) — עדכן סטטוס ל-Archived.

---

## סיכום כלים בשימוש

| שלב | כלי | מטרה |
|------|------|-------|
| חיפוש חברות | Apollo `apollo_mixed_companies_search` | מציאת חברות לפי סגמנט, גודל, מיקום |
| חיפוש אנשים | Apollo `apollo_mixed_people_api_search` | מציאת מקבלי החלטות |
| העשרת לידים | Apollo `apollo_people_match` / `apollo_people_bulk_match` | אימיילים, טלפונים, נתוני חברה |
| מחקר פרופילים | LinkedIn Scraper `search_people` / `get_person_profile` | נתוני LinkedIn מובנים (חוסך טוקנים) |
| שליחת LinkedIn | Chrome MCP `mcp__Claude_in_Chrome__*` | שליחת הודעות בפועל ב-LinkedIn |
| שליחת Email | Zoho Mail `zohomail_send_message` | שליחת cold emails ומייל סיכום |
| שמירת לידים | Apollo `apollo_contacts_create` | שמירה ומעקב ב-CRM |
| סיקוונסים | Apollo `apollo_emailer_campaigns_add_contact_ids` | פולואפ אוטומטי |
| יומן + תבניות | Notion MCP | קריאה ועדכון יומן שליחות |
