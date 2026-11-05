require 'httpclient'

module HangoutsChat
  class Listener < Redmine::Hook::Listener
    def redmine_hangouts_chat_issues_new_after_save(context = {})
      issue = context[:issue]

      thread = thread_for_project issue.project
      url = url_for_project issue.project

      return unless thread
      return if issue.is_private?
      return unless should_chat_message_be_sent(thread, url)

      msg = {
        :project_name => issue.project,
        :author => issue.author.to_s,
        :action => "created",
        :link => object_url(issue),
        :approval_link => approval_link(issue),
        :subject => issue.to_s,
        :mentions => mentions(issue.description)
      }

      widgets = [
        decorated_text("PERSON", I18n.t("field_author"), issue.author.to_s),
        decorated_text("DESCRIPTION", I18n.t("field_subject"), issue.subject, true),
        decorated_text("BOOKMARK", I18n.t("field_status"), issue.status.to_s),
        decorated_text("CLOCK", I18n.t("field_priority"), issue.priority.to_s)
      ]

      widgets << decorated_text("PERSON", I18n.t("field_assigned_to"), issue.assigned_to.to_s) if issue.assigned_to

      widgets << decorated_text("MULTIPLE_PEOPLE", I18n.t("field_watcher"), issue.watcher_users.join(', ')) if Setting.plugin_redmine_hangouts_chat['display_watchers'] == 'yes' and issue.watcher_users.length > 0

      speak msg, thread, [{ :widgets => widgets }], url
    end

    def should_chat_message_be_sent(thread, url)
      unless url
        Rails.logger.debug("ending interacting with google chat because url is #{url}")
        return false
      end
      unless url.start_with?("http")
        Rails.logger.debug("ending interacting with google chat because #{redact url} does not seem to contain a valid URL")
        return false
      end

      Rails.logger.info("found google chat ticket to url #{redact url}")
      Rails.logger.debug("thread #{thread}")
      Rails.logger.debug("google chat url #{redact Setting.plugin_redmine_hangouts_chat['hangouts_chat_url']}")
      Rails.logger.debug("google chat thread #{Setting.plugin_redmine_hangouts_chat['thread']}")

      return true
    end

    def redmine_hangouts_chat_issues_edit_after_save(context = {})
      issue = context[:issue]
      journal = context[:journal]

      thread = thread_for_project issue.project
      url = url_for_project issue.project

      return unless thread and Setting.plugin_redmine_hangouts_chat['post_updates'] == '1'
      return if issue.is_private?
      return if journal.private_notes?

      details = journal.details.reject { |d| ignored_field? d }
      if details.empty? && journal.notes.blank?
        Rails.logger.debug("not sending google chat message for #{issue} because only ignored fields changed")
        return
      end

      return unless should_chat_message_be_sent(thread, url)

      msg = {
        :project_name => issue.project,
        :author => journal.user.to_s,
        :action => "updated",
        :link => object_url(issue),
        :approval_link => approval_link(issue),
        :subject => issue.to_s,
        :mentions => mentions(journal.notes)
      }

      sections = []

      fields = details.map { |d| detail_to_field d }
      sections << { :widgets => fields } if fields.size > 0

      sections << {
        :widgets => [text_paragraph(journal.notes)]
      } if journal.notes.present?

      speak msg, thread, sections, url
    end

    def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context = {})
      issue = context[:issue]
      journal = issue.current_journal
      changeset = context[:changeset]

      thread = thread_for_project issue.project
      url = url_for_project issue.project

      return unless thread
      return if issue.is_private?
      return unless should_chat_message_be_sent(thread, url)

      # Redmine saves the issue itself right after this hook. The changes are
      # reported here, so the following edit notification is suppressed.
      issue.skip_hangouts_chat_notification = true

      msg = {
        :project_name => issue.project,
        :author => (journal ? journal.user : changeset.user).to_s,
        :action => "updated",
        :link => object_url(issue),
        :approval_link => approval_link(issue),
        :subject => issue.to_s
      }

      repository = changeset.repository

      if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
        host, port, prefix = $2, $4, $5
        revision_url = Rails.application.routes.url_for(
          :controller => 'repositories',
          :action => 'revision',
          :id => repository.project,
          :repository_id => repository.identifier_param,
          :rev => changeset.revision,
          :host => host,
          :protocol => Setting.protocol,
          :port => port,
          :script_name => prefix
        )
      else
        revision_url = Rails.application.routes.url_for(
          :controller => 'repositories',
          :action => 'revision',
          :id => repository.project,
          :repository_id => repository.identifier_param,
          :rev => changeset.revision,
          :host => Setting.host_name,
          :protocol => Setting.protocol
        )
      end

      sections = [
        {
          :widgets => [
            text_paragraph(ll(Setting.default_language, :text_status_changed_by_changeset, "<a href=\"#{revision_url}\">#{escape changeset.comments}</a>"), false)
          ]
        }
      ]

      fields = issue.changes.except('updated_on', 'lock_version')
        .map { |attr, (_old, new)| JournalDetail.new(:property => 'attr', :prop_key => attr, :value => new) }
        .reject { |detail| ignored_field? detail }
        .map { |detail| detail_to_field detail }
      sections << { :widgets => fields } if fields.size > 0

      speak msg, thread, sections, url
    end

    def controller_wiki_edit_after_save(context = {})
      return unless Setting.plugin_redmine_hangouts_chat['post_wiki_updates'] == '1'

      project = context[:project]
      page = context[:page]

      user = page.content.author

      thread = thread_for_project project
      url = url_for_project project

      return unless thread
      return unless should_chat_message_be_sent(thread, url)

      sections = []
      sections << {
        :widgets => [text_paragraph(page.content.comments)]
      } if page.content.comments.present?

      msg = {
        :project_name => project,
        :author => user.to_s,
        :action => "updated",
        :subject => page.pretty_title,
        :project_link => object_url(project)
      }

      speak msg, thread, sections, url
    end

    def speak(msg, thread, sections = [], url = nil)
      url = Setting.plugin_redmine_hangouts_chat['hangouts_chat_url'] unless url
      url = url + '&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD' if thread

      buttons = []
      buttons << text_button("OPEN ISSUE", msg[:link]) if msg[:link]
      buttons << text_button("OPEN PROJECT", msg[:project_link]) if msg[:project_link]
      buttons << text_button("FREIGEBEN", msg[:approval_link]) if msg[:approval_link]
      sections += [{ :widgets => [{ :buttonList => { :buttons => buttons } }] }] if buttons.any?

      # header texts are plain text in cardsV2, so they must not be html-escaped
      card = {
        :header => {
          :title => "#{msg[:author]} #{msg[:action]} #{msg[:subject]} #{msg[:mentions]}".strip,
          :subtitle => msg[:project_name].to_s
        },
        :sections => sections
      }

      params = {
        :cardsV2 => [{ :cardId => "redmine", :card => card }]
      }
      params[:thread] = { :threadKey => thread } if thread

      begin
        client = HTTPClient.new
        client.ssl_config.cert_store.set_default_paths
        client.ssl_config.ssl_version = :auto
        client.post_async url, { :body => params.to_json, :header => { 'Content-Type' => 'application/json' } }
      rescue Exception => e
        Rails.logger.warn("cannot connect to #{redact url}")
        Rails.logger.warn(redact("#{e.class}: #{e.message}"))
      end
    end

    private

    # the webhook url contains credentials which allow anybody to post into the space
    def redact(text)
      text.to_s.gsub(/([?&](?:key|token)=)[^&\s]*/, '\1[FILTERED]')
    end

    def text_button(text, url)
      {
        :text => text,
        :onClick => {
          :openLink => {
            :url => url
          }
        }
      }
    end

    # leads to the approval button on the issue page; approving itself needs a logged-in user
    def approval_link(issue)
      return nil unless OrderApproval.applicable?(issue) && OrderApproval.approval_journal(issue).nil?
      "#{object_url(issue)}#order-approval"
    end

    def decorated_text(icon, label, content, multiline = false)
      content = escape content.to_s
      content = "-" if content.empty?
      widget = {
        :decoratedText => {
          :topLabel => label.to_s,
          :text => content,
          :wrapText => multiline
        }
      }
      widget[:decoratedText][:startIcon] = { :knownIcon => icon } if icon
      widget
    end

    def text_paragraph(text, escape_text = true)
      { :textParagraph => { :text => escape_text ? escape(text.to_s) : text.to_s } }
    end

    def escape(msg)
      CGI.escapeHTML msg.to_s
    end

    def object_url(obj)
      if Setting.host_name.to_s =~ /\A(https?:\/\/)?(.+?)(:(\d+))?(\/.+)?\z/i
        host, port, prefix = $2, $4, $5
        Rails.application.routes.url_for(obj.event_url(
          {
            :host => host,
            :protocol => Setting.protocol,
            :port => port,
            :script_name => prefix
          }))
      else
        Rails.application.routes.url_for(obj.event_url(
          {
            :host => Setting.host_name,
            :protocol => Setting.protocol
          }))
      end
    end

    def url_for_project(proj)
      return nil if proj.blank?

      [
        project_setting(proj, "URL"),
        (url_for_project proj.parent),
        Setting.plugin_redmine_hangouts_chat['hangouts_chat_url'],
      ].find { |v| v.present? }
    end

    def thread_for_project(proj)
      return nil if proj.blank?

      val = [
        project_setting(proj, "Thread"),
        (thread_for_project proj.parent),
        Setting.plugin_redmine_hangouts_chat['thread'],
      ].find { |v| v.present? }

      # Channel name '-' is reserved for NOT notifying
      return nil if val.to_s == '-'
      val
    end

    # value of the project custom field "Google Chat <name>"; the former name
    # "Hangouts Chat <name>" is still supported
    def project_setting(proj, name)
      ["Google Chat #{name}", "Hangouts Chat #{name}"].each do |field_name|
        cf = ProjectCustomField.find_by_name(field_name)
        value = (proj.custom_value_for(cf).value rescue nil) if cf
        return value if value.present?
      end
      nil
    end

    def field_key_and_title(detail)
      if detail.property == "cf"
        key = CustomField.find(detail.prop_key).name rescue nil
        title = key
      elsif detail.property == "attachment"
        key = "attachment"
        title = I18n.t :label_attachment
      else
        key = detail.prop_key.to_s.sub("_id", "")
        if key == "parent"
          title = I18n.t "field_#{key}_issue"
        elsif key == "child"
          title = I18n.t "label_subtask"
        else
          title = I18n.t "field_#{key}"
        end
      end
      [key, title]
    end

    # names (custom field names, attribute names or their labels) of fields whose changes are not posted
    def ignored_fields
      Setting.plugin_redmine_hangouts_chat['ignored_fields'].to_s
        .split(/\r?\n/).map { |name| name.strip.downcase }.reject(&:empty?)
    end

    def ignored_field?(detail)
      ignored = ignored_fields
      return false if ignored.empty?
      names = field_key_and_title(detail)
      # also accept attribute names as the REST API lists them, e.g. "priority_id"
      names << detail.prop_key.to_s if detail.property == "attr"
      names.compact.any? { |name| ignored.include? name.to_s.strip.downcase }
    end

    def detail_to_field(detail)
      key, title = field_key_and_title(detail)

      short = true
      value = detail.value.to_s

      case key
      when "title", "subject", "description"
        short = false
      when "tracker"
        value = (Tracker.find(detail.value) rescue nil).to_s
      when "project"
        value = (Project.find(detail.value) rescue nil).to_s
      when "status"
        value = (IssueStatus.find(detail.value) rescue nil).to_s
      when "priority"
        value = (IssuePriority.find(detail.value) rescue nil).to_s
      when "category"
        value = (IssueCategory.find(detail.value) rescue nil).to_s
      when "assigned_to"
        value = (User.find(detail.value) rescue nil).to_s
      when "fixed_version"
        value = (Version.find(detail.value) rescue nil).to_s
      when "attachment"
        attachment = Attachment.find(detail.prop_key) rescue nil
        value = attachment.filename if attachment
      when "parent"
        issue = Issue.find(detail.value) rescue nil
        value = "#{issue.id}" if issue
      end

      decorated_text(nil, title, value, !short)
    end

    def mentions(text)
      return nil if text.nil?
      names = extract_usernames text
      names.present? ? "\nTo: " + names.join(', ') : nil
    end

    def extract_usernames(text = '')
      if text.nil?
        text = ''
      end

      # slack usernames may only contain lowercase letters, numbers,
      # dashes and underscores and must start with a letter or number.
      text.scan(/@[a-z\d][a-z\d_\-]*/).uniq
    end
  end
end
