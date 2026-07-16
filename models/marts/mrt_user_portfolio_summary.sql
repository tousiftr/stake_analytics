-- mrt_user_portfolio_summary.sql
-- Final mart answering: for each user, total invested amount,
-- current estimated portfolio value, and realized net yield,
-- as of 30 June 2024.
--
-- Formulas:
--   total_invested_aed = sum(amount_aed) for completed investments
--   current_portfolio_value_aed = sum(shares_held * price_per_share)
--     where price_per_share = most recent secondary trade price if exists,
--     else AED 500 (original listing price)
--   realized_net_yield = total_distributions_received / total_invested

with total_invested as (
    select
        user_id,
        sum(amount_aed) as total_invested_aed
    from {{ ref('stg_investments') }}
    where status = 'completed'
      and investment_date <= '2024-06-30'
    group by 1
),

portfolio_value as (
    select
        sh.user_id,
        sum(
            sh.shares_held
            * coalesce(mp.market_price_per_share_aed, 500)
        ) as current_portfolio_value_aed
    from {{ ref('int_shares_held') }} sh
    left join {{ ref('int_property_market_price') }} mp
        on sh.property_id = mp.property_id
    group by 1
),

total_distributions as (
    select
        user_id,
        sum(distributions_received_aed) as total_distributions_received_aed
    from {{ ref('int_user_distributions') }}
    group by 1
)

select
    u.user_id,
    u.country,
    u.kyc_status,
    coalesce(ti.total_invested_aed, 0) as total_invested_aed,
    coalesce(pv.current_portfolio_value_aed, 0) as current_portfolio_value_aed,
    coalesce(td.total_distributions_received_aed, 0) as total_distributions_received_aed,
    case
        when coalesce(ti.total_invested_aed, 0) > 0
        then round(
            coalesce(td.total_distributions_received_aed, 0)
            / ti.total_invested_aed,
            4
        )
        else 0
    end as realized_net_yield,
    coalesce(pv.current_portfolio_value_aed, 0)
        - coalesce(ti.total_invested_aed, 0) as unrealized_gain_loss_aed
from {{ ref('stg_users') }} u
left join total_invested ti on u.user_id = ti.user_id
left join portfolio_value pv on u.user_id = pv.user_id
left join total_distributions td on u.user_id = td.user_id
where ti.total_invested_aed is not null
