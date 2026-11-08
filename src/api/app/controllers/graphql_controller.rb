class GraphqlController < ApplicationController
  # Anything unexpected is a bug: it is logged, and the caller only learns that
  # something went wrong. Expected failures never get here (see RoomBookingSchema).
  rescue_from StandardError, with: :internal_error

  # The one API endpoint. It works out who is asking and for which workspace,
  # then runs the whole operation inside that workspace.
  def execute
    # A JSON body cannot be sent by a plain cross-site form, which closes the
    # usual route for request forgery on top of the SameSite cookie.
    return head(:unsupported_media_type) unless request.media_type == "application/json"

    user = Session.find_user(cookies[Session::COOKIE])
    membership = membership_for(user, request.headers["X-Workspace-Id"])
    return render(json: not_a_member) if membership == :none

    context = context_for(user, membership)
    result = if membership
               Tenancy.with(membership.workspace, membership:) { run_operation(context) }
             else
               run_operation(context)
             end
    render json: result
  end

  private

  def run_operation(context)
    RoomBookingSchema.execute(params[:query], variables:, context:, operation_name: params[:operationName])
  end

  def context_for(user, membership)
    { user:, membership:, cookies:, now: Time.current, client_key: request.remote_ip, secure: request.ssl? }
  end

  # nil when no workspace was asked for, :none when the user is not in it.
  def membership_for(user, workspace_id)
    return nil if workspace_id.blank? || user.nil?

    user.memberships.includes(:workspace, :user).find_by(workspace_id:) || :none
  end

  # The same answer for a workspace that does not exist and for one the user is
  # not a member of, so ids cannot be probed.
  def not_a_member
    { errors: [ { message: "Workspace not found.", extensions: { code: "NOT_FOUND", issues: [] } } ] }
  end

  def variables
    given = params[:variables]
    case given
    when ActionController::Parameters then given.to_unsafe_h
    when Hash then given
    else {}
    end
  end

  def internal_error(error)
    logger.error("#{error.class}: #{error.message}\n#{error.backtrace&.first(8)&.join("\n")}")
    render json: { errors: [ { message: "Something went wrong on our side.",
                               extensions: { code: "INTERNAL", issues: [] } } ] },
           status: :internal_server_error
  end
end
