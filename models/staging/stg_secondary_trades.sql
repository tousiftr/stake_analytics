

with source as (
    select * from {{ source('stake_raw', 'raw_secondary_trades') }}
)

select
    trade_id,
    seller_user_id,
    buyer_user_id,
    property_id,
    cast(trade_date as date) as trade_date,
    num_shares,
    price_per_share_aed,
    status
from source
