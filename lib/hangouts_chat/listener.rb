require 'httpclient'

module HangoutsChat
  class Listener < Redmine::Hook::Listener
    def redmine_hangouts_chat_issues_new_after_save(context = {})
      issue = context[:issue]

      thread = thread_for_project issue.project
      url = url_for_project issue.project

      return unless thread and url
      return if issue.is_private?

      msg = {
        :project_name => issue.project,
        :author => issue.author.to_s,
        :action => "created",
        :link => object_url(issue),
        :issue => issue,
        :mentions => "#{mentions issue.description}"
      }

      card = {}

      widgets = [
        {
          :keyValue => {
            :icon => "PERSON",
            :topLabel => I18n.t("field_author"),
            :content => escape(issue.author.to_s),
            :contentMultiline => "false"
          }
        }, {
          :keyValue => {
            :icon => "DESCRIPTION",
            :topLabel => I18n.t("field_subject"),
            :content => escape(issue.subject),
            :contentMultiline => "true"
          }
        }, {
          :keyValue => {
            :icon => "BOOKMARK",
            :topLabel => I18n.t("field_status"),
            :content => escape(issue.status.to_s),
            :contentMultiline => "false"
          }
        }, {
          :keyValue => {
            :icon => "CLOCK",
            :topLabel => I18n.t("field_priority"),
            :content => escape(issue.priority.to_s),
            :contentMultiline => "false"
          }
        }
      ]

      widgets << {
        :keyValue => {
          :icon => "PERSON",
          :topLabel => I18n.t("field_assigned_to"),
          :content => escape(issue.assigned_to.to_s),
          :contentMultiline => "false"
        }
      } if issue.assigned_to

      widgets << {
        :keyValue => {
          :icon => "MULTIPLE_PEOPLE",
          :topLabel => I18n.t("field_watcher"),
          :content => escape(issue.watcher_users.join(', ')),
          :contentMultiline => "false"
        }
      } if Setting.plugin_redmine_hangouts_chat['display_watchers'] == 'yes' and issue.watcher_users.length > 0

      card[:sections] = [
        { :widgets => widgets }
      ]

      speak msg, thread, card, url
    end

    def redmine_hangouts_chat_issues_edit_after_save(context = {})
      issue = context[:issue]
      journal = context[:journal]

      thread = thread_for_project issue.project
      url = url_for_project issue.project

      return unless thread and url and Setting.plugin_redmine_hangouts_chat['post_updates'] == '1'
      return if issue.is_private?
      return if journal.private_notes?

      msg = {
        :project_name => issue.project,
        :author => journal.user.to_s,
        :action => "updated",
        :link => object_url(issue),
        :issue => issue,
        :mentions => "#{mentions journal.notes}"
      }

      card = {
        :sections => [
        ]
      }

      fields = journal.details.map { |d| detail_to_field d }

      card[:sections] << {
        :widgets => fields
      } if fields.size > 0

      card[:sections] << {
        :widgets => [
          {
            :textParagraph => {
              :text => escape(journal.notes)
            }
          }
        ]
      } if journal.notes

      speak msg, thread, card, url
    end

    def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context = {})
      issue = context[:issue]
      journal = issue.current_journal
      changeset = context[:changeset]

      thread = thread_for_project issue.project
      url = url_for_project issue.project

      return unless thread and url and issue.save
      return if issue.is_private?

      msg = {
        :project_name => issue.project,
        :author => journal.user.to_s,
        :action => "updated",
        :link => object_url(issue),
        :issue => issue
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

      card = {
        :header => {
          :title => ll(Setting.default_language, :text_status_changed_by_changeset, "<a href=\"#{revision_url}\">#{escape changeset.comments}</a>")
        },
        :sections => []
      }

      card[:sections] << {
        :widgets => journal.details.map { |d| detail_to_field d }
      }

      speak msg, thread, card, url
    end

    def controller_wiki_edit_after_save(context = {})
      return unless Setting.plugin_redmine_hangouts_chat['post_wiki_updates'] == '1'

      project = context[:project]
      page = context[:page]

      user = page.content.author

      thread = thread_for_project project
      url = url_for_project project

      card = nil
      unless page.content.comments.empty?
        card = {
          :header => {
            :title => "#{escape page.content.comments}"
          }
        }
      end

      comment = {
        :project_name => project,
        :author => user,
        :action => "updated",
        :link => object_url(page),
        :project_link => object_url(project)
      }

      speak comment, thread, card, url
    end

    def speak(msg, thread, card = nil, url = nil)
      url = Setting.plugin_redmine_hangouts_chat['hangouts_chat_url'] unless url
      username = msg[:author]
      icon = Setting.plugin_redmine_hangouts_chat['icon']
      url = url + '&thread_key=' + thread if thread

      card = {
        :header => {
          :title => "#{msg[:author]} #{msg[:action]} #{escape msg[:issue].to_s} #{msg[:mentions]}",
          :subtitle => "#{escape msg[:project_name].to_s}"
        },
        :sections => []
      }

      params = {
        :cards => [card]
      }

      card[:sections] << {
        :widgets => [
          :buttons => [
            text_button("OPEN ISSUE", msg[:link])
          ]
        ]
      } if msg[:link]

      card[:sections] << {
        :widgets => [
          :buttons => [
            text_button("OPEN PROJECT", msg[:project_link])
          ]
        ]
      } if msg[:project_link]

      params[:sender] = { :displayName => username } if username
      params[:thread] = { :threadKey => thread }
      begin
        client = HTTPClient.new
        client.ssl_config.cert_store.set_default_paths
        client.ssl_config.ssl_version = :auto
        client.post_async url, { :body => params.to_json, :header => { 'Content-Type' => 'application/json' } }
      rescue Exception => e
        Rails.logger.warn("cannot connect to #{url}")
        Rails.logger.warn(e)
      end
    end

    private

    def text_button(text, url)
      {
        :textButton => {
          :text => text,
          :onClick => {
            :openLink => {
              :url => url
            }
          }
        }
      }
    end

    def escape(msg)
      CGI.escapeHTML msg
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

      cf = ProjectCustomField.find_by_name("Hangouts Chat URL")

      [
        (proj.custom_value_for(cf).value rescue nil),
        (url_for_project proj.parent),
        Setting.plugin_redmine_hangouts_chat['hangouts_chat_url'],
      ].find { |v| v.present? }
    end

    def thread_for_project(proj)
      return nil if proj.blank?

      cf = ProjectCustomField.find_by_name("Hangouts Chat Thread")

      val = [
        (proj.custom_value_for(cf).value rescue nil),
        (thread_for_project proj.parent),
        Setting.plugin_redmine_hangouts_chat['thread'],
      ].find { |v| v.present? }

      # Channel name '-' is reserved for NOT notifying
      return nil if val.to_s == '-'
      val
    end

    def detail_to_field(detail)
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
        else
          title = I18n.t "field_#{key}"
        end
      end

      short = true
      value = escape detail.value.to_s

      case key
      when "title", "subject", "description"
        short = false
      when "tracker"
        tracker = Tracker.find(detail.value) rescue nil
        value = escape tracker.to_s
      when "project"
        project = Project.find(detail.value) rescue nil
        value = escape project.to_s
      when "status"
        status = IssueStatus.find(detail.value) rescue nil
        value = escape status.to_s
      when "priority"
        priority = IssuePriority.find(detail.value) rescue nil
        value = escape priority.to_s
      when "category"
        category = IssueCategory.find(detail.value) rescue nil
        value = escape category.to_s
      when "assigned_to"
        user = User.find(detail.value) rescue nil
        value = escape user.to_s
      when "fixed_version"
        version = Version.find(detail.value) rescue nil
        value = escape version.to_s
      when "attachment"
        attachment = Attachment.find(detail.prop_key) rescue nil
        value = "<#{object_url attachment}|#{escape attachment.filename}>" if attachment
      when "parent"
        issue = Issue.find(detail.value) rescue nil
        value = "<#{object_url issue}|#{escape issue}>" if issue
      end

      value = "-" if value.empty?

      result = {
        :keyValue => {
          :topLabel => title,
          :content => value
        }
      }
      result[:keyValue][:contentMultiline] = "true" unless short
      result
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