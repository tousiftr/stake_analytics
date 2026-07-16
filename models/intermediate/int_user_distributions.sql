-- int_user_distributions.sql
-- Allocate distributions pro-rata based on shares currently held.
-- Assumption: distributions are allocated based on current holdings,
-- not point-in-time holdings (which would require a full share-ownership
-- timeline, out of scope for this exercise).
-- Per-share distribution = total_distribution_aed / total_shares (property level)
-- User's share = per_share_distribution * shares_held

with dist_per_share as (
    select
        d.property_id,
        d.distribution_id,
        d.distribution_type,
        d.distribution_date,
        d.total_distribution_aed,
        p.total_shares,
        d.total_distribution_aed / nullif(p.total_shares, 0) as per_share_aed
    from {{ ref('stg_distributions') }} d
    inner join {{ ref('stg_properties') }} p
        on d.property_id = p.property_id
    where d.distribution_date <= '2024-06-30'
)

select
    sh.user_id,
    sh.property_id,
    sum(dps.per_share_aed * sh.shares_held) as distributions_received_aed
from {{ ref('int_shares_held') }} sh
inner join dist_per_share dps
    on sh.property_id = dps.property_id
group by 1, 2
