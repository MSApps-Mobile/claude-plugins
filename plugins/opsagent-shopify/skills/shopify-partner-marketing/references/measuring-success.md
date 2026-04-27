# Measuring marketing success

This is the most-tested module on the assessment. Memorize the funnel, the KPIs at each layer, and the attribution-model trade-offs.

## The marketing funnel for Shopify Partners

```
Reach        →   awareness (impressions, reach, organic traffic)
   ↓
Engage       →   sign-ups, content downloads, follows, repeat visits
   ↓
Capture      →   marketing-qualified lead (MQL) — provided contact info
   ↓
Qualify      →   sales-qualified lead (SQL) — meets ICP, has buying signal
   ↓
Pipeline     →   discovery call booked, opportunity created
   ↓
Close        →   contract signed, project starts
   ↓
Expand       →   referrals, retainers, Plus migration upsell, app revenue share
```

KPIs ladder up. Marketing's job is to feed the top of the funnel and improve conversion at each stage. Don't measure only the top.

## KPIs — the small set that matters

Pick **3–5 primary KPIs** maximum. The Academy is firm on this — too many KPIs dilute focus.

For most Shopify Partners, the core set is:

1. **Marketing-sourced pipeline ($).** Total $ value of opportunities marketing generated.
2. **Cost per opportunity (CPO).** Marketing spend ÷ # opportunities created.
3. **Conversion rate by funnel stage.** MQL→SQL, SQL→Opportunity, Opportunity→Closed-won.
4. **Win rate.** Closed-won ÷ Closed-total.
5. **Customer acquisition cost (CAC).** Total marketing+sales spend ÷ new customers acquired.
6. **CAC:LTV ratio.** Healthy partner agencies aim for 1:3+ (LTV at least 3x CAC).
7. **Time-to-close.** Days from first touch to signed contract.

Avoid: total impressions, total followers, total leads (without quality filter).

## Attribution models

The exam tests whether you can pick the right model for the situation.

| Model | How it works | When to use |
|---|---|---|
| **First-touch** | 100% credit to the first interaction | Simple campaigns; awareness-focused; long-cycle B2B with single dominant channel |
| **Last-touch** | 100% credit to the final interaction | Late-funnel optimization; very short cycles |
| **Linear** | Equal credit to every touch | When you don't trust any specific weighting; baseline against more complex models |
| **U-shaped (position-based)** | 40% first, 40% last, 20% middle | Lead-gen with clear hooks at top + bottom; common B2B default |
| **W-shaped** | 30% first, 30% MQL conversion, 30% opportunity, 10% middle | More mature funnels with distinct conversion events |
| **Time-decay** | Recent touches get more credit | Long sales cycles where recency matters |
| **Data-driven** | ML-derived weights from your historical data | Mature programs with enough data |

For a Shopify Partner just starting attribution: **start with linear**. Graduate to U-shaped once you have 6–12 months of clean data. Skip data-driven until you have 100+ closed-won deals to train on.

## Multi-touch attribution — why it matters for partner GTM

Most Shopify Partner deals are touched 7–15 times before close. If you only credit last-touch, you'll over-invest in late-funnel channels (direct outreach) and starve the awareness channels (content, podcasts, webinars) that originated the deal.

Concrete example:
- A merchant reads your blog post (touch 1).
- Sees you on a webinar (touch 3).
- Gets your cold email (touch 5).
- Clicks an ad and books a call (touch 7).

Last-touch credits the ad with 100% of revenue → you double down on ads → blog and webinar lose budget → next quarter the funnel collapses because awareness dried up.

Multi-touch attribution gives partial credit to all 4 touches → balanced budget → sustainable funnel.

## Reporting cadence

- **Weekly:** Pipeline created, meetings booked, channel spend pacing.
- **Monthly:** Conversion rates by stage, CPO, top-performing content.
- **Quarterly:** CAC, LTV, win rate, ICP-fit of closed-won, channel-mix performance, attribution-derived investment recommendations.
- **Annually:** Strategic review — ICPs, positioning, channel-mix, full unit economics.

## Dashboards — keep them ruthless

A good marketing dashboard has 5–10 numbers, not 50. Each number should drive a decision. Numbers that don't drive a decision get cut.

Useful framing — for every metric on the dashboard, ask:
- What action would change if this number doubled?
- What action would change if it halved?

If neither has an answer, remove the metric.

## Tools for partner-scale measurement

- **CRM:** HubSpot, Pipedrive, Salesforce, or a tight Notion+Sheets system for very early stage.
- **Web analytics:** GA4 + Plausible / Fathom for privacy-respecting alternative.
- **Attribution:** HubSpot built-in for early stage; Dreamdata / Bizible / HockeyStack at $5M+ revenue.
- **Heatmaps:** Hotjar / Microsoft Clarity for landing-page optimization.
- **Email:** Customer.io / HubSpot / Mailchimp.
- **LinkedIn analytics:** native + Shield for personal-page tracking.
- **Search Console + Ahrefs / Semrush** for SEO performance.

## Common measurement mistakes

- **No baseline.** Without before/after, every campaign looks "successful."
- **Too many KPIs.** Dilution of focus = no decisions made.
- **Last-touch attribution.** Distorts channel mix toward late-funnel.
- **Reporting without a recommendation.** "Here are the numbers" without "so we should do X" wastes the dashboard.
- **Not tracking ICP fit.** A high lead volume of out-of-ICP traffic looks great on dashboards but rots the sales pipeline.
- **Ignoring negative signals.** Unsubscribes, bounce rate, time-to-disqualify — these matter as much as conversions.

## Tying back to revenue

Every campaign and channel must terminate in **$** at some point. Funnel KPIs are intermediate; revenue is the only one that matters at year-end.

For each ICP × channel combination, you should know:
- Cost-per-meeting
- Meeting-to-opportunity rate
- Opportunity-to-close rate
- Average deal size
- Payback period (time to recoup CAC)

If those numbers don't roll up, the system isn't measurable yet — fix the instrumentation before optimizing the spend.

## The "reach the right people" mantra

Shopify's framing throughout the course: **reach the right people, with the right message, on the right channel, at the right time.** Measurement is how you know you did each one.

- Wrong people = ICP miss.
- Wrong message = positioning miss.
- Wrong channel = channel-fit miss.
- Wrong time = trigger / cadence miss.

Your dashboard should reveal which of the four is broken when results lag. Otherwise it's just numbers.

## Output checklist

- [ ] 3–5 primary KPIs picked, no more.
- [ ] Each KPI ladders up to revenue.
- [ ] Attribution model chosen and matches funnel maturity.
- [ ] Reporting cadence defined (weekly / monthly / quarterly).
- [ ] Dashboard has only numbers that drive decisions.
- [ ] CAC:LTV ratio tracked.
- [ ] ICP-fit of pipeline tracked, not just volume.
- [ ] Each campaign has a defined success threshold *before* it launches.
