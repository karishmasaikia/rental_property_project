{{
    config(
        materialized = 'table'
    )
}}

with

daily_changes as (

    select
        listing_change_id,
        listing_id,
        -- changed_at is a timestamp but the calendar is daily, so ranges are dates to join on calendar_date
        cast(changed_at as date) as valid_from_date,
        amenities,
        _loaded_at

    from {{ ref('stg_rental__amenities_changelog') }}

    -- if a listing's amenities change more than once on the same day, keep only the latest change of that day
    qualify row_number() over (
        partition by listing_id, cast(changed_at as date)
        order by changed_at desc
    ) = 1

)

select
    listing_change_id,
    listing_id,
    valid_from_date,
    coalesce(
        lead(valid_from_date) over (partition by listing_id order by valid_from_date),
        date '9999-12-31'
    ) as valid_to_date,
    lead(valid_from_date) over (
        partition by listing_id order by valid_from_date
    ) is null as is_current,
    amenities,
    _loaded_at
from daily_changes
