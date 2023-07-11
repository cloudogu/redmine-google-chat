require 'redmine'

# require_dependency 'redmine_hangouts_chat/listener'

Redmine::Plugin.register :redmine_hangouts_chat do
	name 'Redmine Google Chat'
	author 'Samuel Cormier-Iijima'
	url 'https://github.com/cloudogu/redmine-google-chat'
	description 'Google Chat integration'
	version '0.3.0'

	requires_redmine :version_or_higher => '0.8.0'

	settings \
		:default => {
			'callback_url' => 'https://chat.googleapis.com/v1/',
			'thread' => nil,
			'username' => 'redmine',
			'display_watchers' => 'no'
		},
		:partial => 'settings/hangouts_chat_settings'
end

Issue.send(:include, HangoutsChat::IssuePatch)
