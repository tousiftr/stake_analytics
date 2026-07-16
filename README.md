# Stake — Analytics Engineer Case Study
**Submitted by**: Tousif Alam (Rad)
**Date**: July 2026

---

## How to Run This Project

I used **dbt Core + DuckDB**, the simplest setup with no cloud accounts or credentials needed. Everything runs locally.

```bash
# Clone the repo
git clone https://github.com/tousiftr/stake_analytics.git
cd stake_analytics

# Set up Python environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Mac/Linux

# Install dbt
pip install dbt-core dbt-duckdb
```

Create `~/.dbt/profiles.yml`:

```yaml
stake_analytics:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: stake.duckdb
      threads: 4
```

Then build everything:

```bash
dbt seed     # loads raw CSVs into DuckDB
dbt build    # runs models + tests
dbt docs generate && dbt docs serve   # opens documentation site
```

---

## How I Structured the Project

I followed the staging → intermediate → mart pattern that mirrors your Hevo → dbt → Lightdash pipeline.

```
seeds/ (5 raw CSVs)
  │
  ├── staging/
  │     ├── stg_users                 — deduplicated, cleaned types
  │     ├── stg_properties            — backfilled null total_shares
  │     ├── stg_investments           — deduplicated, kept orphans visible
  │     ├── stg_distributions         — cast dates, no issues found
  │     └── stg_secondary_trades      — cast dates, no issues found
  │
  ├── intermediate/
  │     ├── int_shares_held           — net shares per user per property
  │     ├── int_property_market_price — most recent secondary trade price
  │     └── int_user_distributions    — pro-rata distribution allocation
  │
  └── marts/
        └── mrt_user_portfolio_summary — one row per user, answers the business question
```

**Why this structure**: Each staging model is a 1:1 clean of its raw source, so downstream models never touch raw data directly. The intermediate layer isolates the three trickiest pieces of logic (share ownership, market pricing, distribution allocation) into individually testable units. The mart combines them into the final answer.

---

## What I Found in the Data

| Table | Issue | What I Did |
|-------|-------|------------|
| raw_users | 1 duplicate user_id | Deduplicated, kept the earliest by signup_date |
| raw_users | Nulls in country, email, referral_source | Left as-is. These don't affect the portfolio calculation, and imputing them would be guesswork |
| raw_properties | P004 has null total_shares | Backfilled using `total_value_aed / price_per_share_aed`, which is the inverse of the formula in the brief |
| raw_investments | 1 exact duplicate row | Deduplicated by investment_id |
| raw_investments | 1 orphan user_id, 1 orphan property_id | Kept the rows and surfaced them via relationship tests at warn severity. I chose visibility over silent filtering, so the team can investigate the root cause upstream |
| raw_secondary_trades | 2 of 32 trades are cancelled | Filtered to completed only in the intermediate layer, since cancelled trades shouldn't move shares or set prices |

---

## My Assumptions

These are the judgment calls I made where the brief left room for interpretation:

1. **Cutoff date**: All calculations are as of 30 June 2024, per the brief.

2. **Only completed investments count**: I excluded cancelled, pending, and refunded investments from total_invested and share counts. Pending investments haven't settled, and the other two statuses mean the money didn't stay in.

3. **Only completed trades move shares**: Cancelled secondary trades don't affect share holdings or market pricing.

4. **Portfolio value pricing**: I default to AED 500/share (original listing price). If a property has at least one completed secondary trade, I use the most recent trade's price for that property. This applies to all holders of that property, not just the parties in the trade, since the market price reflects the property's current valuation.

5. **Distribution allocation (the biggest assumption)**: I allocated distributions pro-rata based on **current** share holdings, not point-in-time historical holdings. The brief says "based on shares currently held," which I read as current-state. Building a full share-ownership timeline with snapshots would give more accurate results but was out of scope for 3-4 hours. I'd flag this as the first thing to improve in production.

6. **Realized net yield**: `total_distributions_received / total_invested`. This is a simple cash-on-cash return, separate from any paper gain/loss on share value. I kept this intentionally simple because yield and capital appreciation are different lenses the business should track independently.

7. **Zero holdings excluded**: If a user sold all shares in a property via the secondary market, that property drops out of their portfolio. Users who sold everything across all properties don't appear in the mart.

---

## How I Approached Testing

I focused tests where data issues would silently break the numbers, not on every column:

- **Primary keys** (unique + not_null): All staging model IDs. If these fail, everything downstream is wrong.
- **Referential integrity**: `stg_investments.user_id → stg_users` and `stg_investments.property_id → stg_properties`. Set to warn severity because orphans exist in the raw data and I want to see them, not hide them.
- **Accepted values**: Status fields in investments (`completed/cancelled/pending/refunded`), trades (`completed/cancelled`), and distribution_type (`rental_income/capital_gain`). A new unexpected value here would mean the business logic needs updating.
- **Mart-level**: Unique user_id (the grain must be one row per user) and not_null on financial columns that downstream reporting depends on.

I intentionally skipped tests on columns like `country` or `email` where nulls exist but don't affect the calculation. Testing those would generate noise without protecting anything.

---

## BI Dashboard

**Tableau Public**: [View the Dashboard](https://public.tableau.com/app/profile/tousif.alam8303/viz/Stake_17841869627210/Dashboard1)

**Built for**: Investor Relations and Product teams.

**What it answers**:
- How much has been invested across the platform, and what is it worth today?
- Which users have the highest portfolio value and yield?
- How are yields distributed, are most users in a healthy range?
- Where is the KYC compliance risk?

**Key insights from the data**:
- **60 users** have completed investments totaling **AED 3.5M**, with a current portfolio value of **AED 3.6M** (net gain of AED 125K).
- Most users cluster between **6-10% realized yield**, which is healthy for a fractional real estate platform.
- **AED 975K+ sits with users in "rejected" KYC status**. This is the most actionable finding, the IR team should prioritize clearing these users or escalating to compliance.
- 3 users (U0059, U0042, U0034) show yields above 16%. These aren't anomalies, they bought shares cheaply on the secondary market, so their distributions are high relative to a small primary investment.

---

## What I Would Do Differently in Production

1. **Point-in-time distributions**: Build a share ownership timeline using dbt snapshots, so each distribution is allocated to whoever actually held shares on that distribution date. This is the highest-value improvement.

2. **Secondary market pricing**: Instead of only the most recent trade, use a volume-weighted average price (VWAP) across recent trades for a more stable and defensible valuation.

3. **Incremental materialization**: At scale, the mart should be built incrementally rather than full-refresh, especially as the investments and trades tables grow.

4. **Data quality monitoring**: Add a framework like dbt-expectations or Elementary for anomaly detection on incoming raw data, catching issues before they reach the mart.

5. **Lightdash integration**: Since the team uses Lightdash, I'd connect the DuckDB warehouse (or MotherDuck for cloud access) directly and define metrics in the .yml files so Lightdash picks them up natively.
