{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key = 'listing_day_id',
        on_schema_change = 'fail'
    )
}}

with

-- an amenity change can affect days already in this table (future days loaded in advance, or a change
-- that arrives late): incremental runs rebuild new calendar rows plus every day of listings whose amenities changed
{% if is_incremental() %}
amenity_listings_to_update as (

    select distinct listing_id
    from {{ ref('int_listing_amenities_history') }}
    where _loaded_at >= (select max(amenities_loaded_at) from {{ this }})

),
{% endif %}

updated_calendar as (

    select *
    from {{ ref('stg_rental__calendar') }}

    {% if is_incremental() %}
    where _loaded_at >= (select max(calendar_loaded_at) from {{ this }})
        or listing_id in (select listing_id from amenity_listings_to_update)
    {% endif %}

),

updated_amenities as (

    select *
    from {{ ref('int_listing_amenities_history') }}
    {% if is_incremental() %}
    where listing_id in (select listing_id from updated_calendar)
    {% endif %}

)

select
    calendar.listing_day_id,
    calendar.listing_id,
    calendar.calendar_date,
    calendar.is_available,
    calendar.reservation_id,
    calendar.reservation_id is not null as is_booked,
    calendar.daily_price_usd,
    calendar.minimum_nights,
    calendar.maximum_nights,
    amenities.listing_change_id,
    amenities.amenities,
    calendar._loaded_at as calendar_loaded_at,
    amenities._loaded_at as amenities_loaded_at
from updated_calendar as calendar
left join updated_amenities as amenities
    on calendar.listing_id = amenities.listing_id
    and calendar.calendar_date >= amenities.valid_from_date
    and calendar.calendar_date < amenities.valid_to_date
