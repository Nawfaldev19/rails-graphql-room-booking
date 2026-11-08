# Serves the built web app for every page address. The web app does its own
# routing in the browser, so each of them gets the same HTML file.
class PagesController < ApplicationController
  INDEX = Rails.public_path.join("index.html")

  def show
    if INDEX.exist?
      # The page is tiny and names the current asset files, so it is always
      # checked for a newer version.
      expires_now
      send_file INDEX, type: "text/html", disposition: "inline"
    else
      render plain: "The web app has not been built yet. Run bin/demo from the project root.",
             status: :not_found
    end
  end
end
