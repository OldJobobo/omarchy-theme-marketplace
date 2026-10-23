# Every public page: home, guide, the artists index, each theme and each artist. lastmod is the
# theme's last push (an artist's latest push across their themes), else when the catalog was built.
built = catalog.generated_at

xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  page = lambda do |loc, lastmod|
    xml.url do
      xml.loc loc
      xml.lastmod lastmod.utc.iso8601 if lastmod
    end
  end

  page.(root_url, built)
  page.(guide_url, nil)
  page.(artists_url, built)
  catalog.themes.each { |theme| page.(theme_url(theme), theme.pushed_at || built) }
  catalog.artists.each do |login|
    page.(artist_url(login), catalog.by_artist(login).filter_map(&:pushed_at).max || built)
  end
end
