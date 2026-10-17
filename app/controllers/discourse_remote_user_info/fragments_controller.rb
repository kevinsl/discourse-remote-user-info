# frozen_string_literal: true

module ::DiscourseRemoteUserInfo
  # Serves the remote fragment from the forum's own origin.
  #
  # The browser could call the remote system directly, but then the fragment
  # would need CORS headers there and a widened connect-src here, and nothing
  # could be cached or sanitised. Proxying keeps all of that server-side.
  class FragmentsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    # The user card is shown to anonymous visitors, so this cannot require a
    # login — but it must respect whatever the forum lets a visitor see, which
    # fetch_user does. check_xhr is deliberately left in place: this is only
    # ever called by the front end, so it should answer an ajax request or a
    # .json path and nothing else.

    def show
      user = fetch_user

      # Say nothing about who exists: an unknown name and a name this visitor
      # may not see give the same answer.
      return head(:no_content) if user.blank?

      html = Fetcher.fragment(user.username, view)
      return head(:no_content) if html.blank?

      render json: { html: html }
    end

    private

    def fetch_user
      user = User.find_by_username_or_email(params[:username].to_s)
      return nil if user.blank?
      return nil unless guardian.can_see_user?(user)
      user
    end

    def view
      v = params[:view].to_s
      %w[card summary].include?(v) ? v : "card"
    end
  end
end
