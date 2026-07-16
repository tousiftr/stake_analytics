# Stake Analytics Engineer — Take-Home Case Study
 
## Setup
 
**Stack**: dbt Core 1.11 + DuckDB (local, no cloud accounts needed)
 
### How to reproduce
 
```bash
# 1. Clone and set up
git clone https://github.com/tousiftr/stake_analytics.git
cd stake_analytics
 
# 2. Create virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # Mac/Linux
 
# 3. Install dependencies
pip install dbt-core dbt-duckdb
 
# 4. Configure profile — create ~/.dbt/profiles.yml with:
```
 
```yaml
stake_analytics:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: stake.duckdb
      threads: 4
```
 
```bash
# 5. Load raw data and build all models + tests
dbt seed
dbt build
 
# 6. Generate and view documentation
dbt docs generate
dbt docs serve
```
 
## Architecture
 
```
seeds/ (5 raw CSVs loaded via dbt seed)
  │
  ├── staging/ (1:1 with raw — dedup, cast, clean)
  │     ├── stg_users
  │     ├── stg_properties
  │     ├── stg_investments
  │     ├── stg_distributions
  │     └── stg_secondary_trades
  │
  ├── intermediate/ (business logic building blocks)
  │     ├── int_shares_held          ← net shares per user per property
  │     ├── int_property_market_price ← latest secondary trade price
  │     └── int_user_distributions   ← pro-rata distribution allocation
  │
  └── marts/ (final business-facing model)
        └── mrt_user_portfolio_summary
```
 
## Data Quality Issues Found & Handled
 
| Table | Issue | Resolution |
|-------|-------|------------|
| raw_users | 1 duplicate user_id | Deduplicated, kept earliest by signup_date |
| raw_users | Nulls in country, email, referral_source | Kept as-is. Not needed for portfolio calculation |
| raw_properties | P004 has null total_shares | Backfilled as total_value_aed / price_per_share_aed |
| raw_investments | 1 exact duplicate row | Deduplicated by investment_id |
| raw_investments | 1 orphan user_id, 1 orphan property_id | Surfaced via relationship tests (warn severity), not silently dropped |
| raw_secondary_trades | 2 of 32 trades are cancelled | Filtered to completed only in intermediate models |
 
## Key Assumptions
 
1. **Cutoff date**: All calculations are as of 30 June 2024 per the brief.
2. **Only completed investments count**: Cancelled, pending, and refunded investments are excluded from total_invested and share counts.
3. **Only completed secondary trades move shares**: Cancelled trades do not affect holdings or market price.
4. **Portfolio value pricing**:
   - Default price per share = AED 500 (original listing price).
   - If a property has at least one completed secondary trade, the most recent trade's price replaces the AED 500 default for all holders of that property.
5. **Distribution allocation — pro-rata by current holdings**:
   - Per-share distribution = total_distribution_aed / total_shares (at the property level).
   - Each user receives: per_share_distribution × shares_currently_held.
   - This uses **current holdings**, not point-in-time historical holdings. A full share-ownership timeline was considered out of scope for a 3-4 hour exercise. In production, I would build a snapshot-based approach to track ownership changes over time.
   - Both rental_income and capital_gain distribution types are included.
6. **Realized net yield** = total_distributions_received / total_invested. This is a cash-on-cash return, separate from any paper gain/loss from share price movement.
7. **Zero or negative share holdings are excluded**: If a user sold all shares in a property via secondary trades, that property no longer appears in their portfolio.
## Testing Strategy
 
Tests are placed where the data risk actually is, not blanket coverage:
 
- **Primary keys**: unique + not_null on all staging model IDs
- **Referential integrity**: relationship tests on investments → users and investments → properties (warn severity, since orphans exist in raw data and we want visibility, not silent failure)
- **Accepted values**: status fields in investments and trades, distribution_type in distributions
- **Mart-level**: unique + not_null on user_id, not_null on key financial columns
## BI Dashboard
 
**Tableau Public**: [Stake — User Portfolio Summary](https://public.tableau.com/app/profile/tousif.alam8303/viz/Stake_17841869627210/Dashboard1)
 
 
**What it shows**:
- KPI scorecards: total users, invested amount, portfolio value, avg yield, unrealized gain
- Top 15 investors by invested amount vs current portfolio value
- Yield distribution across all users (most cluster between 6-10%)
- Investment breakdown by country and KYC status
- Scatter plot of yield vs investment size

 
## What I Would Do Differently in Production
 
1. **Point-in-time distribution allocation**: Build a share ownership timeline using snapshots, so distributions are allocated to whoever held shares on each distribution date, not just current holders.
2. **Secondary market price modeling**: Rather than using only the most recent trade, consider a volume-weighted average price (VWAP) across recent trades for a more stable valuation.
3. **Incremental models**: The mart would be materialized incrementally for performance at scale.
4. **Data quality layer**: Add a dedicated data quality framework (e.g. dbt expectations or elementary) for anomaly detection on incoming raw data
