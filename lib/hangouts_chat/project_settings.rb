module HangoutsChat
  # Plugin settings which can be overridden for a project and its subprojects by a
  # project custom field named "Google Chat <name>", e.g. "Google Chat Post Issue Updates".
  module ProjectSettings
    # setting key => name of the project custom field without "Google Chat"
    NAMES = {
      'hangouts_chat_url' => "URL",
      'thread' => "Thread",
      'thread_per_issue' => "One Thread per Issue",
      'display_watchers' => "Display Watchers",
      'post_updates' => "Post Issue Updates",
      'post_wiki_updates' => "Post Wiki Updates",
      'post_description' => "Post Description",
      'ignored_fields' => "Ignored Fields",
      'order_approval' => "Order Approval"
    }.freeze

    def self.global(key)
      Setting.plugin_redmine_hangouts_chat[key]
    end

    # value of the project custom field of the project or its parents; without
    # one, the plugin setting
    def self.value(project, key)
      return global(key) if project.nil?

      field_value(project, key).presence || value(project.parent, key)
    end

    # like value, for yes/no settings: boolean project custom fields are "1" or "0",
    # plugin settings "1" or "yes"
    def self.enabled?(project, key)
      %w[1 yes].include? value(project, key).to_s
    end

    # value of the project custom field of the project only; the former name
    # "Hangouts Chat <name>" is still supported
    def self.field_value(project, key)
      name = NAMES.fetch(key)
      ["Google Chat #{name}", "Hangouts Chat #{name}"].each do |field_name|
        field = ProjectCustomField.find_by_name(field_name)
        value = (project.custom_value_for(field).value rescue nil) if field
        return value if value.present?
      end
      nil
    end
  end
end
