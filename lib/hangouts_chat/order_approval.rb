module HangoutsChat
  # Orders are issues whose subject contains "Bestellung". They can be approved
  # once by adding the note "ist freigegeben".
  module OrderApproval
    SUBJECT_PATTERN = /bestellung/i
    NOTE = "ist freigegeben"
    # boolean project custom field which enables or disables the approval for a
    # project and its subprojects
    PROJECT_FIELD = "Google Chat Order Approval"

    # enabled by the project custom field of the project or its parents; without
    # a value there, by the plugin settings
    def self.enabled?(project)
      return Setting.plugin_redmine_hangouts_chat['order_approval'] == '1' if project.nil?

      value = project_value(project)
      value.present? ? value == '1' : enabled?(project.parent)
    end

    def self.project_value(project)
      field = ProjectCustomField.find_by_name(PROJECT_FIELD)
      field && project.custom_value_for(field)&.value
    end

    def self.applicable?(issue)
      issue.subject.to_s.match?(SUBJECT_PATTERN) && enabled?(issue.project)
    end

    def self.approval_journal(issue)
      issue.journals.where(:notes => NOTE).order(:id).first
    end

    def self.approvable?(issue, user = User.current)
      applicable?(issue) && issue.notes_addable?(user) && approval_journal(issue).nil?
    end
  end
end
