# sitemap.xml and robots.txt. Both are rendered rather than static so their URLs use the host the
# site is served on, like the canonical links on every page.
class SeoController < ApplicationController
  def sitemap
  end

  def robots
    render plain: "User-agent: *\nAllow: /\n\nSitemap: #{sitemap_url}\n"
  end
end
