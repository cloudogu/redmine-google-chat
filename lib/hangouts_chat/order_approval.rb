module HangoutsChat
  # Orders are issues whose subject contains "Bestellung". They can be approved
  # once by adding the note "ist freigegeben".
  module OrderApproval
    SUBJECT_PATTERN = /bestellung/i
    NOTE = "ist freigegeben"

    def self.applicable?(issue)
      issue.subject.to_s.match?(SUBJECT_PATTERN) && ProjectSettings.enabled?(issue.project, 'order_approval')
    end

    def self.approval_journal(issue)
      issue.journals.where(:notes => NOTE).order(:id).first
    end

    # an order which is not approved yet
    def self.pending?(issue)
      applicable?(issue) && approval_journal(issue).nil?
    end

    def self.approvable?(issue, user = User.current)
      pending?(issue) && issue.notes_addable?(user)
    end
  end
end
