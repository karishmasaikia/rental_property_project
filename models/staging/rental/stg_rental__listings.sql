{{
    config(
        materialized = 'view'
    )
}}

with

renamed as (

    select
        cast(id as integer) as listing_id,
        name as listing_name,
        cast(host_id as integer) as host_id,
        host_name as host_name,
        cast(host_since as timestamp) as host_since_at,
        host_location as host_location,
        from_json(host_verifications, '["VARCHAR"]') as host_verifications,
        neighborhood as neighborhood,
        lower(regexp_replace(property_type, '^(entire|private room in|shared room in|room in)\s+', '', 'i')) as property_type,
        room_type as room_type,
        cast(accommodates as integer) as accommodates,
        coalesce(
            cast(regexp_extract(bathrooms_text, '^[0-9.]+') as decimal(3, 1)),
            0
        ) as bathroom_count,
        case
            when bathrooms_text ilike '%shared%' then 'shared'
            when bathrooms_text ilike '%private%' then 'private'
            else 'not specified'
        end as bathroom_privacy,
        coalesce(cast(bedrooms as integer), 0) as bedrooms,
        cast(beds as integer) as beds,
        cast(replace(replace(price, '$', ''), ',', '') as decimal(10, 2)) as first_calendar_price_usd,
        cast(number_of_reviews as integer) as number_of_reviews,
        cast(first_review as date) as first_review_date,
        cast(last_review as date) as last_review_date,
        cast(review_scores_rating as double) as review_scores_rating_avg,
        _loaded_at

    from {{ source('rental', 'listings') }}

    where id is not null
        and coalesce(name, '') not ilike 'testing%'

)

select *
from renamed
qualify row_number() over (
    partition by listing_id
    order by _loaded_at desc
) = 1
