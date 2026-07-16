-- stg_distributions.sql
-- Clean data, no duplicates or orphans found.
-- Both rental_income and capital_gain types are kept for yield calculation.

with source as (
    select * from {{ source('stake_raw', 'raw_distributions') }}
)

select
    distribution_id,
    property_id,
    cast(period_start as date) as period_start,
    cast(period_end as date) as period_end,
    cast(distribution_date as date) as distribution_date,
    distribution_type,
    total_distribution_aed
from source
