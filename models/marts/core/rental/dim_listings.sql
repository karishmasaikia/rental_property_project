{{
    config(
        materialized = 'table'
    )
}}

select
    listing_id,
    listing_name,
    neighborhood,
    property_type,
    room_type,
    accommodates,
    bathroom_count,
    bathroom_privacy,
    bedrooms,
    beds,
    first_calendar_price_usd,
    number_of_reviews,
    first_review_date,
    last_review_date,
    review_scores_rating_avg,
    host_id,
    host_name,
    host_since_at,
    host_location,
    host_verifications
from {{ ref('stg_rental__listings') }}
