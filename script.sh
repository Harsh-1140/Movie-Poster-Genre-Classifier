# Your TMDB Bearer Token (v4 auth)
TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJmNTFiYTlhZTAyYWY0OGE2NGZjYmU5MTQyNjhhMWRmMSIsIm5iZiI6MTc2MjU3ODcyMi4yNTQwMDAyLCJzdWIiOiI2OTBlZDEyMjAwNDE5NTQ2MDhhMGJmNjgiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.FZh-2yb4jNZksh3gPotdh-IDzEwCH140g5FuIUwKq0U"

OUTDIR="tmdb_results"
mkdir -p "$OUTDIR"

TOTAL_PAGES=3212

for PAGE in $(seq 1 $TOTAL_PAGES); do
    echo "Fetching page $PAGE..."

    while true; do
        # Make request and capture HTTP code + body
        HTTP_CODE=$(curl --silent --write-out "%{http_code}" --output "$OUTDIR/page_${PAGE}.json.tmp" \
          --request GET \
          --url "https://api.themoviedb.org/3/discover/movie?with_original_language=en&sort_by=popularity.desc&region=US&primary_release_date.gte=2000-01-01&with_genres=35|53&page=$PAGE" \
          --header "accept: application/json" \
          --header "Authorization: Bearer $TOKEN")

        if [ "$HTTP_CODE" -eq 200 ]; then
            mv "$OUTDIR/page_${PAGE}.json.tmp" "$OUTDIR/page_${PAGE}.json"
            echo "Page $PAGE saved."
            break
        else
            echo "Request failed (HTTP $HTTP_CODE). Retrying in 2s..."
            sleep 2
        fi
    done

    # small delay to avoid rate limit
    sleep 0.2
done

echo "Done. All pages downloaded into $OUTDIR/"
