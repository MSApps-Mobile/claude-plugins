# Priority Score Algorithm — Reference

## Formula

```
Priority Score = (Business Impact × Urgency × Dependency Weight) / Normalized Token Cost
```

## Factor Definitions

### Business Impact (1-10)

| Score | Meaning | Examples |
|-------|---------|---------|
| 9-10 | Revenue-critical, deadline-driven | Monthly invoicing, hot lead response |
| 7-8 | Revenue-supporting, client-facing | LinkedIn lead review, xplace bids |
| 5-6 | Business-building, internal value | Plugin development, migration |
| 3-4 | Operational hygiene | Receipt matching, backups |
| 1-2 | Nice-to-have monitoring | Health checks, presence monitoring |

### Urgency (1-5)

| Score | Meaning |
|-------|---------|
| 5 | Due today, hard deadline |
| 4 | Due today, soft deadline |
| 3 | Due this week |
| 2 | No specific deadline |
| 1 | Can be deferred indefinitely |

### Dependency Weight

| Score | Meaning |
|-------|---------|
| 1.2 | Self-contained (no external deps) |
| 1.0 | Normal dependencies |
| 0.8 | Heavy dependencies (3+), higher failure risk |

### Normalized Token Cost

Maps avg_tokens to a 1-10 scale:
- 5K tokens → factor 1
- 50K tokens → factor 5
- 100K tokens → factor 10

This ensures expensive tasks need proportionally higher impact to rank well.

## Example Rankings

| Task | Impact | Urgency | Deps | Tokens | Score |
|------|--------|---------|------|--------|-------|
| Aman invoicing | 9 | 5 | 1.0 | 45K (4.5) | 10.0 |
| Hot lead response | 8 | 5 | 1.0 | 20K (2.0) | 20.0 |
| LinkedIn review | 8 | 4 | 1.0 | 35K (3.5) | 9.1 |
| Gali WhatsApp | 7 | 3 | 1.0 | 15K (1.5) | 14.0 |
| Plugin dev | 5 | 2 | 1.2 | 60K (6.0) | 2.0 |
| Toggl check | 2 | 1 | 1.0 | 5K (1.0) | 2.0 |

## Dynamic Re-ranking

After each task completes, the orchestrator:
1. Updates remaining budget
2. Checks if any urgency changed (e.g., time-sensitive task now past deadline)
3. Re-sorts the queue
4. Presents updated ranking to user if order shifted
