class ApplicationController < ActionController::API
  # API-only controllers leave cookie handling out. The session token travels in
  # a cookie, so it is added back here.
  include ActionController::Cookies
end
