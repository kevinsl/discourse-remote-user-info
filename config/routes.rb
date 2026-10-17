# frozen_string_literal: true

DiscourseRemoteUserInfo::Engine.routes.draw { get "/:username" => "fragments#show" }

Discourse::Application.routes.draw do
  mount ::DiscourseRemoteUserInfo::Engine, at: "/remote-user-info"
end
