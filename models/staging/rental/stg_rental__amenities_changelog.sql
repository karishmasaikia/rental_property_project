{{
    config(
        materialized = 'view'
    )
}}

with

renamed as (

    select
        cast(listing_id as integer) as listing_id,
        cast(change_at as timestamp) as changed_at,
        list_transform(
            from_json(amenities, '["VARCHAR"]'),
            lambda a: lower(trim(a))
        ) as amenities,
        _loaded_at

    from {{ source('rental', 'amenities_changelog') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['listing_id', 'changed_at']) }} as listing_change_id,
    *
from renamed
qualify row_number() over (
    partition by listing_id, changed_at
    order by _loaded_at desc
) = 1
