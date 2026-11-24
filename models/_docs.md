{% docs calendar_date %}
The date this row describes.
{% enddocs %}

{% docs is_available %}
True if the listing could be booked on this date, false if not.
{% enddocs %}

{% docs reservation_id %}
Identifier of the reservation covering this date. Null when the listing was not reserved.
{% enddocs %}

{% docs daily_price_usd %}
Price in USD to rent the listing on this date, whether or not it was booked.
{% enddocs %}

{% docs minimum_nights %}
Minimum number of consecutive nights a stay must last, as set by the host for this date.
{% enddocs %}

{% docs maximum_nights %}
Maximum number of consecutive nights a stay may last, as set by the host for this date. Can change over time
for the same listing.
{% enddocs %}

{% docs amenities %}
Full list of amenities available to guests (e.g. wifi, kitchen). Names are lowercased and trimmed in staging,
so filter with the lowercase name: list_contains(amenities, 'air conditioning'). Matching is exact, so
spelling variants (e.g. 'wi-fi') don't match.
{% enddocs %}

{% docs listing_name %}
Display name of the listing.
{% enddocs %}

{% docs neighborhood %}
Neighborhood where the listing is located.
{% enddocs %}

{% docs property_type %}
Type of property in lowercase, without the room-type wording (e.g. "Private room in house" becomes "house").
{% enddocs %}

{% docs room_type %}
Type of room offered (e.g. Entire home/apt, Private room).
{% enddocs %}

{% docs accommodates %}
Number of guests the listing can accommodate.
{% enddocs %}

{% docs bathroom_count %}
Number of bathrooms, parsed from the source bathrooms_text (e.g. "1.5 shared baths" gives 1.5). A missing
value is treated as 0.
{% enddocs %}

{% docs bathroom_privacy %}
Whether guests share the bathroom, parsed from the source bathrooms_text: shared, private, or not specified
when the text doesn't say (e.g. "1 bath") or is missing.
{% enddocs %}

{% docs bedrooms %}
Number of bedrooms. Missing values are treated as 0.
{% enddocs %}

{% docs beds %}
Number of beds available.
{% enddocs %}

{% docs first_calendar_price_usd %}
Nightly price in USD as of the first day of the calendar's date range, converted from text ('$125.00') to a
number. A one-time snapshot that is not updated over time; use daily_price_usd for the price on a given date.
{% enddocs %}

{% docs number_of_reviews %}
Number of reviews the listing has received to date.
{% enddocs %}

{% docs first_review_date %}
Date of the listing's first review.
{% enddocs %}

{% docs last_review_date %}
Date of the listing's most recent review.
{% enddocs %}

{% docs review_scores_rating_avg %}
Average review score of the listing to date.
{% enddocs %}

{% docs host_id %}
Identifier of the host who owns the listing.
{% enddocs %}

{% docs host_name %}
Display name of the host.
{% enddocs %}

{% docs host_since_at %}
When the host signed up.
{% enddocs %}

{% docs host_location %}
Where the host is based, as free text from the source (e.g. "Boston, Massachusetts, United States", "US").
{% enddocs %}

{% docs host_verifications %}
List of methods the host can use to verify their identity (e.g. email, phone), parsed from the source JSON
array.
{% enddocs %}
