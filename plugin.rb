# frozen_string_literal: true

# name: discourse-remote-user-info
# about: Shows a row of information about a user, fetched from another system, on the user card and profile summary.
# version: 0.1.0
# authors: Kevin Lewandowski
# url: https://github.com/kevinsl/discourse-remote-user-info
# required_version: 2.7.0

enabled_site_setting :remote_user_info_enabled

register_asset "stylesheets/common/remote-user-info.scss"

module ::DiscourseRemoteUserInfo
  PLUGIN_NAME = "discourse-remote-user-info"
end

require_relative "lib/discourse_remote_user_info/engine"

after_initialize do
  require_relative "lib/discourse_remote_user_info/fetcher"
end
