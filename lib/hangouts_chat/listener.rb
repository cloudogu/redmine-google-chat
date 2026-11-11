require 'httpclient'
require 'securerandom'

module HangoutsChat
  class Listener < Redmine::Hook::Listener
    # Thread name '-' is reserved for NOT notifying
    DISABLED_THREAD = '-'

    # attributes whose value is the id of a record, shown by the name of the record
    RECORD_ATTRIBUTES = {
      "tracker" => "Tracker",
      "project" => "Project",
      "status" => "IssueStatus",
      "priority" => "IssuePriority",
      "category" => "IssueCategory",
      "assigned_to" => "User",
      "fixed_version" => "Version"
    }.freeze

    # attributes whose value is shown on several lines
    LONG_ATTRIBUTES = %w[title subject description].freeze

    # Google Chat accepts messages up to 32,000 bytes
    MAX_TEXT_BYTES = 30_000

    def redmine_hangouts_chat_issues_new_after_save(context = {})
      issue = context[:issue]
      return if issue.is_private?

      url = chat_url issue.project
      return unless url

      widgets = [
        decorated_text("PERSON", I18n.t("field_author"), issue.author.to_s),
        decorated_text("DESCRIPTION", I18n.t("field_subject"), issue.subject, true),
        decorated_text("BOOKMARK", I18n.t("field_status"), issue.status.to_s),
        decorated_text("CLOCK", I18n.t("field_priority"), issue.priority.to_s)
      ]
      widgets << decorated_text("PERSON", I18n.t("field_assigned_to"), issue.assigned_to.to_s) if issue.assigned_to
      if ProjectSettings.enabled?(issue.project, 'display_watchers') && issue.watcher_users.any?
        widgets << decorated_text("MULTIPLE_PEOPLE", I18n.t("field_watcher"), issue.watcher_users.join(', '))
      end

      thread = issue_thread issue
      reply = description_reply issue
      # the description is posted to the thread of the message; without a thread,
      # the message starts a thread of its own
      thread ||= "redmine-issue-#{issue.id}-#{SecureRandom.hex(4)}" if reply

      msg = issue_message(issue, issue.author, "created", issue.description)
      speak msg, thread, [{ :widgets => widgets }], url, reply
    end

    def redmine_hangouts_chat_issues_edit_after_save(context = {})
      issue = context[:issue]
      journal = context[:journal]
      return if issue.is_private? || journal.private_notes?
      return unless ProjectSettings.enabled?(issue.project, 'post_updates')

      url = chat_url issue.project
      return unless url

      sections = []
      fields = detail_fields(issue.project, journal.details)
      sections << { :widgets => fields } if fields.any?
      sections << { :widgets => [text_paragraph(journal.notes)] } if journal.notes.present?
      if sections.empty?
        Rails.logger.debug("not sending google chat message for #{issue} because only ignored fields changed")
        return
      end

      msg = issue_message(issue, journal.user, "updated", journal.notes)
      speak msg, issue_thread(issue), sections, url
    end

    def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context = {})
      issue = context[:issue]
      changeset = context[:changeset]
      return if issue.is_private?

      url = chat_url issue.project
      return unless url

      # Redmine saves the issue itself right after this hook. The changes are
      # reported here, so the following edit notification is suppressed.
      issue.skip_hangouts_chat_notification = true

      repository = changeset.repository
      revision_url = Rails.application.routes.url_for(url_options.merge(
        :controller => 'repositories',
        :action => 'revision',
        :id => repository.project,
        :repository_id => repository.identifier_param,
        :rev => changeset.revision
      ))
      revision_link = "<a href=\"#{revision_url}\">#{escape changeset.comments}</a>"
      sections = [{
        :widgets => [text_paragraph(ll(Setting.default_language, :text_status_changed_by_changeset, revision_link), false)]
      }]

      changes = issue.changes.except('updated_on', 'lock_version').map do |attr, (_old, new)|
        JournalDetail.new(:property => 'attr', :prop_key => attr, :value => new)
      end
      fields = detail_fields(issue.project, changes)
      sections << { :widgets => fields } if fields.any?

      journal = issue.current_journal
      msg = issue_message(issue, journal ? journal.user : changeset.user, "updated")
      speak msg, issue_thread(issue), sections, url
    end

    def controller_wiki_edit_after_save(context = {})
      project = context[:project]
      page = context[:page]
      return unless ProjectSettings.enabled?(project, 'post_wiki_updates')

      url = chat_url project
      return unless url

      sections = []
      sections << { :widgets => [text_paragraph(page.content.comments)] } if page.content.comments.present?

      msg = {
        :project_name => project,
        :author => page.content.author.to_s,
        :action => "updated",
        :subject => page.pretty_title,
        :project_link => object_url(project)
      }
      speak msg, thread_for_project(project), sections, url
    end

    private

    # posts the message, and the reply to the thread of the message
    def speak(msg, thread, sections, url, reply = nil)
      url += '&messageReplyOption=REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD' if thread

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

      messages = [params]
      messages << { :text => reply, :thread => { :threadKey => thread } } if reply && thread

      Rails.logger.info("sending google chat message to #{redact url}#{" in thread #{thread}" if thread}")
      post_in_background url, messages
    end

    # posts the messages one after another in the background, so a reply follows its message
    def post_in_background(url, messages)
      Thread.new do
        client = HTTPClient.new
        client.ssl_config.cert_store.set_default_paths
        client.ssl_config.ssl_version = :auto
        messages.each do |params|
          response = client.post url, { :body => params.to_json, :header => { 'Content-Type' => 'application/json' } }
          next if response.status.between?(200, 299)

          Rails.logger.warn("google chat answered #{response.status}: #{redact response.body.to_s.truncate(500)}")
          break
        end
      rescue StandardError => e
        Rails.logger.warn("cannot connect to #{redact url}")
        Rails.logger.warn(redact("#{e.class}: #{e.message}"))
      end
    end

    # description of a new issue, posted as reply to its message
    def description_reply(issue)
      return nil unless ProjectSettings.enabled?(issue.project, 'post_description')

      plain_text(issue.description).presence&.truncate_bytes(MAX_TEXT_BYTES)
    end

    # Redmine stores line breaks as "\r\n", which Google Chat shows as two line breaks;
    # several empty lines are reduced to one
    def plain_text(text)
      text.to_s.gsub(/\r\n?/, "\n").gsub(/[ \t]+$/, '').gsub(/\n{3,}/, "\n\n").strip
    end

    # webhook url for the messages of the project, nil if they are not posted
    def chat_url(project)
      return nil if notifications_disabled? project

      url = ProjectSettings.value(project, 'hangouts_chat_url')
      unless url.to_s.start_with?("http")
        Rails.logger.debug("not sending google chat message because #{redact url.inspect} is no valid URL")
        return nil
      end
      url
    end

    def issue_message(issue, author, action, text = nil)
      {
        :project_name => issue.project,
        :author => author.to_s,
        :action => action,
        :link => object_url(issue),
        :approval_link => approval_link(issue),
        :subject => issue.to_s,
        :mentions => mentions(text)
      }
    end

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
      "#{object_url(issue)}#order-approval" if OrderApproval.pending?(issue)
    end

    def decorated_text(icon, label, content, multiline = false)
      content = escape plain_text(content)
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
      text = plain_text(text)
      { :textParagraph => { :text => escape_text ? escape(text) : text } }
    end

    def escape(msg)
      CGI.escapeHTML msg.to_s
    end

    # host, port and sub path of Redmine for links in the messages
    def url_options
      if Setting.host_name.to_s =~ /\A(https?:\/\/)?(.+?)(:(\d+))?(\/.+)?\z/i
        { :host => $2, :port => $4, :script_name => $5, :protocol => Setting.protocol }
      else
        { :host => Setting.host_name, :protocol => Setting.protocol }
      end
    end

    def object_url(obj)
      Rails.application.routes.url_for(obj.event_url(url_options))
    end

    def notifications_disabled?(proj)
      configured_thread(proj).to_s == DISABLED_THREAD
    end

    # thread of the project; without one, every message is posted on its own
    def thread_for_project(proj)
      val = configured_thread proj
      val.to_s == DISABLED_THREAD ? nil : val.presence
    end

    # thread of the project, its parents or the plugin settings, including '-';
    # a '-' of a parent project is not inherited
    def configured_thread(proj)
      return nil if proj.blank?

      parent = configured_thread proj.parent
      [
        ProjectSettings.field_value(proj, 'thread'),
        (parent unless parent.to_s == DISABLED_THREAD),
        ProjectSettings.global('thread'),
      ].find { |v| v.present? }
    end

    # thread for messages about the issue. With "Thread per Issue" each issue gets
    # a thread "<thread>-issue-<id>", or "redmine-issue-<id>" without a thread
    def issue_thread(issue)
      thread = thread_for_project issue.project
      return thread unless ProjectSettings.enabled?(issue.project, 'thread_per_issue')
      "#{thread || 'redmine'}-issue-#{issue.id}"
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

    # card fields for the changes, without the ignored fields
    def detail_fields(project, details)
      ignored = ignored_fields project
      details.reject { |detail| ignored_field?(detail, ignored) }.map { |detail| detail_to_field detail }
    end

    # names (custom field names, attribute names or their labels) of fields whose changes are not posted
    def ignored_fields(project)
      ProjectSettings.value(project, 'ignored_fields').to_s
        .split(/\r?\n/).map { |name| name.strip.downcase }.reject(&:empty?)
    end

    def ignored_field?(detail, ignored)
      return false if ignored.empty?
      names = field_key_and_title(detail)
      # also accept attribute names as the REST API lists them, e.g. "priority_id"
      names << detail.prop_key.to_s if detail.property == "attr"
      names.compact.any? { |name| ignored.include? name.to_s.strip.downcase }
    end

    def detail_to_field(detail)
      key, title = field_key_and_title(detail)
      value = detail.value.to_s

      if key == "attachment"
        value = Attachment.find_by(:id => detail.prop_key)&.filename || value
      elsif RECORD_ATTRIBUTES.key?(key)
        value = RECORD_ATTRIBUTES[key].constantize.find_by(:id => detail.value).to_s
      end

      decorated_text(nil, title, value, LONG_ATTRIBUTES.include?(key))
    end

    # "@name" mentions in the text, added to the message title
    def mentions(text)
      names = text.to_s.scan(/@[a-z\d][a-z\d_\-]*/).uniq
      names.any? ? "\nTo: " + names.join(', ') : nil
    end
  end
end
