

with source as (
    select * from {{ source('stake_raw', 'raw_users') }}
),

deduped as (
    select
        *,
        row_number() over (partition by user_id order by signup_date) as rn
    from source
)

select
    user_id,
    cast(signup_date as date) as signup_date,
    country,
    kyc_status,
    email,
    referral_source
from deduped
where rn = 1
