-- stg_properties.sql
-- Backfill 1 null total_shares (P004) using total_value_aed / price_per_share_aed.
-- No duplicates found in raw data.

with source as (
    select * from {{ source('stake_raw', 'raw_properties') }}
)

select
    property_id,
    property_name,
    area,
    property_type,
    total_value_aed,
    price_per_share_aed,
    coalesce(
        total_shares,
        total_value_aed / nullif(price_per_share_aed, 0)
    ) as total_shares,
    cast(listing_date as date) as listing_date,
    expected_annual_yield_pct,
    status
from source
