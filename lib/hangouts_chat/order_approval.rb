module HangoutsChat
  # Orders are issues whose subject contains "Bestellung". They can be approved
  # once by adding the note "ist freigegeben".
  module OrderApproval
    SUBJECT_PATTERN = /bestellung/i
    NOTE = "ist freigegeben"

    def self.applicable?(issue)
      issue.subject.to_s.match?(SUBJECT_PATTERN)
    end

    def self.approval_journal(issue)
      issue.journals.where(:notes => NOTE).order(:id).first
    end

    def self.approvable?(issue, user = User.current)
      applicable?(issue) && issue.notes_addable?(user) && approval_journal(issue).nil?
    end
  end
end
