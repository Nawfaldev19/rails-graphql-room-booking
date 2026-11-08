# Sends GraphQL operations through the real HTTP endpoint, signed in or not.
module GraphqlRequests
  def cookie_for(membership_or_user)
    account = membership_or_user.is_a?(Membership) ? membership_or_user.user : membership_or_user
    token, = Session.start(account)
    "#{Session::COOKIE}=#{token}"
  end

  # as: a membership (signs in and selects its workspace), a user, or nil.
  def gql(query, variables: {}, as: nil, workspace: nil, headers: {})
    request_headers = { "Content-Type" => "application/json" }.merge(headers)
    request_headers["Cookie"] = cookie_for(as) if as
    workspace ||= as.workspace if as.is_a?(Membership)
    request_headers["X-Workspace-Id"] = workspace.id.to_s if workspace
    post "/graphql", params: { query:, variables: }.to_json, headers: request_headers
    response.parsed_body
  end

  def data = response.parsed_body["data"]
  def error_code = response.parsed_body.dig("errors", 0, "extensions", "code")
  def error_issues = response.parsed_body.dig("errors", 0, "extensions", "issues")
end
