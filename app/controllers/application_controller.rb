class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :catalog

  rescue_from NotFound do
    # HTML whatever the path ends in: a slug like "foo.json" would otherwise ask for a JSON template.
    render "errors/not_found", status: :not_found, formats: :html
  end

  private

  def catalog
    @catalog ||= Catalog.current
  end
end
