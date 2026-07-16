-- int_shares_held.sql
-- Net shares held per user per property as of the analysis date.
-- Shares bought via primary market (completed investments)
-- + shares bought via secondary market (as buyer, completed trades)
-- - shares sold via secondary market (as seller, completed trades)

with bought_primary as (
    select
        user_id,
        property_id,
        sum(num_shares) as shares
    from {{ ref('stg_investments') }}
    where status = 'completed'
    group by 1, 2
),

bought_secondary as (
    select
        buyer_user_id as user_id,
        property_id,
        sum(num_shares) as shares
    from {{ ref('stg_secondary_trades') }}
    where status = 'completed'
    group by 1, 2
),

sold_secondary as (
    select
        seller_user_id as user_id,
        property_id,
        sum(num_shares) as shares
    from {{ ref('stg_secondary_trades') }}
    where status = 'completed'
    group by 1, 2
),

combined as (
    select user_id, property_id, shares, 'bought_primary' as source
    from bought_primary
    union all
    select user_id, property_id, shares, 'bought_secondary'
    from bought_secondary
    union all
    select user_id, property_id, -shares, 'sold_secondary'
    from sold_secondary
)

select
    user_id,
    property_id,
    sum(shares) as shares_held
from combined
group by 1, 2
having sum(shares) > 0
