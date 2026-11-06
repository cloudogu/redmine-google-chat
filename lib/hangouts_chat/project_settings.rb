module HangoutsChat
  # Plugin settings which can be overridden for a project and its subprojects by a
  # project custom field named "Google Chat <setting>", e.g. "Google Chat Post Issue Updates".
  module ProjectSettings
    # value of the project custom field "Google Chat <name>" of the project or its
    # parents; without one, the plugin setting <key>
    def self.value(project, name, key)
      return Setting.plugin_redmine_hangouts_chat[key] if project.nil?

      field_value(project, name).presence || value(project.parent, name, key)
    end

    # like value, for checkboxes: boolean project custom fields are "1" or "0",
    # plugin settings "1" or "yes"
    def self.enabled?(project, name, key)
      %w[1 yes].include? value(project, name, key).to_s
    end

    # value of the project custom field "Google Chat <name>" of the project only;
    # the former name "Hangouts Chat <name>" is still supported
    def self.field_value(project, name)
      ["Google Chat #{name}", "Hangouts Chat #{name}"].each do |field_name|
        field = ProjectCustomField.find_by_name(field_name)
        value = (project.custom_value_for(field).value rescue nil) if field
        return value if value.present?
      end
      nil
    end
  end
end
