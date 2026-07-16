-- int_property_market_price.sql
-- For properties with at least one completed secondary trade,
-- use the most recent trade's price as market price.
-- Properties with no secondary trades default to AED 500 in the mart.

-- int_property_market_price.sql
with ranked as (
    select
        property_id,
        price_per_share_aed,
        trade_date,
        row_number() over (
            partition by property_id
            order by trade_date desc
        ) as rn
    from {{ ref('stg_secondary_trades') }}
    where status = 'completed'
)

select
    property_id,
    price_per_share_aed as market_price_per_share_aed,
    trade_date as latest_trade_date
from ranked
where rn = 1