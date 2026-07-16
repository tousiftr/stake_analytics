-- stg_investments.sql
-- Deduplicate raw_investments (1 exact duplicate row found).
-- Orphan user_id and property_id exist; surfaced via relationship tests
-- rather than silently dropped here.

with source as (
    select * from {{ source('stake_raw', 'raw_investments') }}
),

deduped as (
    select
        *,
        row_number() over (partition by investment_id order by investment_date) as rn
    from source
)

select
    investment_id,
    user_id,
    property_id,
    cast(investment_date as date) as investment_date,
    num_shares,
    price_per_share_aed,
    amount_aed,
    status
from deduped
where rn = 1
