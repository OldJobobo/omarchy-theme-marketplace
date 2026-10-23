require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "home renders the gallery from the catalog" do
    get root_path
    assert_response :success
    assert_select "body[style]", count: 0
    assert_select "h1, p", /Community Themes/
    assert_select "turbo-frame#gallery"
    assert_select "[data-slot=card]", minimum: 1
    assert_select "[data-slot=card] span[title='GitHub stars']", minimum: 1
    assert_select "[data-slot=card] a[title='GitHub stars']", count: 0
    assert_select "footer"
    assert_select "header nav a", text: "Guide", count: 0
    assert_select "header a[href=?]", guide_path, text: "Submit a theme"
    assert_select "#submit", count: 0
  end

  test "home shows a top artists leaderboard in the stats section" do
    get root_path
    assert_response :success
    assert_select "#figures" do
      assert_select "[data-slot=card]", minimum: 1
      assert_select "ol li", minimum: 1
      assert_select "ol li:first-of-type a[href=?]", artist_path(top_artist)
      assert_select "[data-slot=card-action] a[href=?]", artists_path, text: "All artists"
    end
  end

  test "home filters, searches and pages via params" do
    get root_path(filter: "light")
    assert_response :success
    assert_select "a[aria-pressed=true]", text: "Light"
    assert_select "a[aria-pressed=false][href*='filter=dark']", text: "Dark"

    get root_path(filter: "all", q: "nujabes")
    assert_response :success
    assert_select "a[href=?]", theme_path("nujabes")

    get root_path(filter: "all", page: 2)
    assert_response :success
    assert_select "nav[aria-label=pagination] a[aria-current=page]", text: "2"
    assert_select "nav[aria-label=pagination] a[href*='page=3']"
  end

  test "home answers turbo frame requests with the frame" do
    get root_path(filter: "dark"), headers: { "Turbo-Frame" => "gallery" }
    assert_response :success
    assert_select "turbo-frame#gallery"
  end

  test "theme page shows install command, palette and og tags" do
    get theme_path("nujabes")
    assert_response :success
    assert_select "h1", "Nujabes"
    assert_select "figure img[alt='Nujabes theme preview'][width='1200']"
    assert_select "dl dd a[href=?]", artist_path("HalmyLyseas"), text: "HalmyLyseas"
    assert_select "dl dd a.font-mono[href*='/commit/']"
    assert_select "dl dd time"
    assert_select "code", "omarchy theme install nujabes"
    assert_select "code", text: /https:/, count: 0
    assert_select "[data-preview=terminal]"
    assert_select "[data-preview=editor]"
    assert_select "[data-preview=fastfetch]"
    assert_select "[data-preview=desktop]"
    assert_select "[style*='--p-accent: #']"
    assert_select "body[style*='--primary: light-dark(']"
    assert_select "[data-controller=copy]", minimum: 2
    assert_select "meta[property='og:image']"
    assert_select "a[href=?]", artist_path("HalmyLyseas")
  end

  test "theme page shows similar themes and links to its accent" do
    get theme_path("nujabes")
    assert_select "h2", "Similar themes"
    assert_select "a[href*='color=%23b26ac6']", text: /Find themes with this accent/
  end

  test "gallery searches by colour" do
    get root_path(color: "#b26ac6", filter: "all")
    assert_response :success
    assert_select "#gallery-state[data-color='#b26ac6']"
    assert_select "input[type=color][value='#b26ac6']"
    assert_select "a[aria-label='Clear colour']"
    assert_select "#gallery-sort", count: 0
  end

  test "/themes redirects to the gallery" do
    get "/themes"
    assert_redirected_to root_path(anchor: "themes")
  end

  test "unknown theme is a 404" do
    get theme_path("does-not-exist")
    assert_response :not_found
  end

  test "a dot in the slug is part of the slug, not a format" do
    assert_equal "/themes/nujabes.v2", theme_path("nujabes.v2")
    get "/themes/nujabes.v2"
    assert_response :not_found
    get "/themes/nujabes.json"
    assert_response :not_found
  end

  test "artists index lists every artist ranked by theme count" do
    get artists_path
    assert_response :success
    assert_select "h1", /\A\d+ Artists\z/
    assert_select "ol li", count: Catalog.new(Catalog.snapshot).artists.size
    assert_select "ol li:first-of-type a[href=?]", artist_path(top_artist)
    assert_select "ol li a[href=?]", artist_path("HalmyLyseas")

    get artists_path(sort: "name")
    assert_response :success
    first = Catalog.new(Catalog.snapshot).artists.min_by(&:downcase)
    assert_select "ol li:first-of-type a[href=?]", artist_path(first)
    assert_select "select#artists-sort option[selected][value=name]"
  end

  test "artist page lists themes" do
    get artist_path("HalmyLyseas")
    assert_response :success
    assert_select "h1", /HalmyLyseas/
    assert_select "[data-slot=card]", minimum: 1
    get artist_path("nobody-here-xyz")
    assert_response :not_found
  end

  test "guide renders as one page with the submission flow" do
    get guide_path
    assert_response :success
    assert_select "article h1", count: 0 # the page opens with its intro, no heading
    assert_select "article h2#make-a-theme"
    assert_select "article h2#submit-a-theme"
    assert_select "article h2#what-gets-checked"
    assert_select "article h2#install-update-and-remove"
    assert_select "article a[href=?]", Rails.configuration.x.submit_url
    assert_select "nav[aria-label='On this page'] a[href='#submit-a-theme']"
    get guide_page_path("nope")
    assert_response :not_found
    get guide_page_path("api") # hidden for now
    assert_response :not_found
    get guide_page_path("making-a-theme") # merged into the single page now
    assert_response :not_found
  end

  test "gallery cards offer the thumbnail in a srcset" do
    get root_path
    theme = Catalog.new(Catalog.snapshot).themes.find(&:featured?)
    assert_select "[data-slot=card] img[srcset*=?][srcset*=?][sizes][loading=lazy]",
      "#{theme.thumb} 480w", "#{theme.image} 1200w"
  end

  test "theme page hero image loads first" do
    get theme_path("nujabes")
    assert_select "figure img[fetchpriority=high]"
    assert_select "figure img[loading]", count: 0
  end

  test "home canonical drops gallery params and the page has social tags" do
    get root_path(filter: "light", page: 2)
    assert_response :success
    assert_select "link[rel=canonical][href=?]", root_url
    assert_select "meta[property='og:url'][content=?]", root_url
    assert_select "meta[property='og:image'][content^='https://']"
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
  end

  test "artists, artist and guide pages have canonical and og tags" do
    { artists_path(sort: "name") => artists_url, artist_path("HalmyLyseas") => artist_url("HalmyLyseas"),
      guide_path => guide_url }.each do |path, canonical|
      get path
      assert_response :success
      assert_select "link[rel=canonical][href=?]", canonical
      assert_select "meta[property='og:title']"
      assert_select "meta[property='og:image']"
    end
    assert_select "meta[name=description][content*=?]", "submit it to the marketplace"
  end

  test "artist pages redirect to the catalog's spelling of the login" do
    get artist_path("halmylyseas")
    assert_response :moved_permanently
    assert_redirected_to artist_path("HalmyLyseas")
  end

  test "sitemap lists the pages, every theme and every artist" do
    get sitemap_path
    assert_response :success
    assert_equal "application/xml", response.media_type
    catalog = Catalog.new(Catalog.snapshot)
    xml = Nokogiri::XML(response.body)
    xml.remove_namespaces!
    locs = xml.xpath("//url/loc").map(&:text)
    assert_includes locs, root_url
    assert_includes locs, guide_url
    assert_includes locs, artists_url
    assert_includes locs, theme_url("nujabes")
    assert_includes locs, artist_url("HalmyLyseas")
    assert_equal 3 + catalog.size + catalog.artists.size, locs.size
    nujabes = xml.xpath("//url[loc=$loc]/lastmod", nil, loc: theme_url("nujabes")).text
    assert_equal catalog.find("nujabes").pushed_at.utc.iso8601, nujabes
  end

  test "robots.txt allows everything and points at the sitemap" do
    get "/robots.txt"
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match(/^Allow: \/$/, response.body)
    assert_match(/^Sitemap: #{Regexp.escape(sitemap_url)}$/, response.body)
  end

  private
    # Derived from the snapshot, not hardcoded: the catalog is refreshed regularly
    # and a bulk import can hand the lead to a different artist at any time.
    def top_artist = Catalog.new(Catalog.snapshot).artist_stats.first[:login]
end
