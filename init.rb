require 'redmine'

Redmine::Plugin.register :redmine_hangouts_chat do
	name 'Redmine Google Chat'
	author 'Cloudogu GmbH, based on the work of Samuel Cormier-Iijima and Tomi Pakarinen'
	author_url 'https://cloudogu.com'
	url 'https://github.com/cloudogu/redmine-google-chat'
	description 'Posts new issues, issue updates and wiki updates to Google Chat spaces via incoming webhooks, ' \
		'with a space and thread per project or a thread per issue, ignored fields and order approval'
	version '0.6.0'

	requires_redmine :version_or_higher => '0.8.0'

	settings \
		:default => {
			'thread' => nil,
			'display_watchers' => 'no',
			'ignored_fields' => ''
		},
		:partial => 'settings/hangouts_chat_settings'
end

Issue.send(:include, HangoutsChat::IssuePatch)

# load the hooks explicitly, otherwise they are only registered when eager loading is enabled
HangoutsChat::Listener
HangoutsChat::OrderApprovalHook
