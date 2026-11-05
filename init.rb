require 'redmine'

Redmine::Plugin.register :redmine_hangouts_chat do
	name 'Redmine Google Chat'
	author 'Samuel Cormier-Iijima'
	url 'https://github.com/cloudogu/redmine-google-chat'
	description 'Google Chat integration'
	version '0.5.0'

	requires_redmine :version_or_higher => '0.8.0'

	settings \
		:default => {
			'callback_url' => 'https://chat.googleapis.com/v1/',
			'thread' => nil,
			'username' => 'redmine',
			'display_watchers' => 'no',
			'ignored_fields' => ''
		},
		:partial => 'settings/hangouts_chat_settings'
end

Issue.send(:include, HangoutsChat::IssuePatch)

# load the hooks explicitly, otherwise they are only registered when eager loading is enabled
HangoutsChat::Listener
HangoutsChat::OrderApprovalHook
