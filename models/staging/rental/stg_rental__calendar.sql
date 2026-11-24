-- incremental, unlike the other staging views: the calendar is the largest source, grows every day,
-- and needs deduplication, so each run only processes newly loaded rows
{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = 'listing_day_id',
        on_schema_change = 'fail'
    )
}}

with

renamed as (

    select
        cast(listing_id as integer) as listing_id,
        cast(date as date) as calendar_date,
        cast(available as boolean) as is_available,
        cast(nullif(reservation_id, 'NULL') as integer) as reservation_id,
        cast(price as decimal(10, 2)) as daily_price_usd,
        cast(minimum_nights as integer) as minimum_nights,
        cast(maximum_nights as integer) as maximum_nights,
        _loaded_at

    from {{ source('rental', 'calendar') }}

    {% if is_incremental() %}
    where _loaded_at >= (select max(_loaded_at) from {{ this }})
    {% endif %}

)

select
    {{ dbt_utils.generate_surrogate_key(['listing_id', 'calendar_date']) }} as listing_day_id,
    *
from renamed
qualify row_number() over (
    partition by listing_id, calendar_date
    order by _loaded_at desc
) = 1
