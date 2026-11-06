# Redmine Google Chat

A Redmine plugin that posts new issues, issue updates and wiki updates to
[Google Chat](https://workspace.google.com/products/chat/) spaces via incoming webhooks.

## Features

- Messages as Google Chat cards with an **OPEN ISSUE** button
- Space and thread configurable per project, inherited by subprojects
- Optionally one thread per issue
- Ignored fields whose changes are not posted
- Order approval with a button in Redmine and in the chat
- Private issues and private notes are never posted

## Requirements

- Redmine (tested with Redmine 7.0)
- The `httpclient` gem, installed with `bundle install`
- An [incoming webhook](https://developers.google.com/workspace/chat/quickstart/webhooks) of the
  Google Chat space

## Installation

Clone the plugin into the `plugins` directory of Redmine. The directory must be named
`redmine_hangouts_chat`:

```sh
cd /path/to/redmine/plugins
git clone https://github.com/cloudogu/redmine-google-chat.git redmine_hangouts_chat
bundle install
```

Restart Redmine. The plugin is then listed under *Administration › Plugins*.

### Cloudogu EcoSystem

Copy the plugin to `/var/tmp/redmine/plugins/redmine_hangouts_chat` in the Redmine Dogu and
restart the Dogu. It installs the plugin and its gems on startup. To update, replace the
directory and restart again.

## Configuration

Open *Administration › Plugins › Redmine Google Chat › Configure*.

| Setting               | Description                                                                      |
|-----------------------|----------------------------------------------------------------------------------|
| Google Chat URL       | Webhook URL of the Google Chat space                                             |
| Google Chat Thread    | Thread for the messages, see [Threads](#threads)                                 |
| One Thread per Issue? | Posts all messages about an issue to a thread of its own                         |
| Display Watchers?     | Lists the watchers in messages about new issues                                  |
| Post Issue Updates?   | Posts issue updates; new issues are always posted                                |
| Post Wiki Updates?    | Posts wiki updates                                                               |
| Ignored Fields        | Fields whose changes are not posted, see [Ignored fields](#ignored-fields)       |

### Per project

Create project custom fields (*Administration › Custom fields › Project*) to override the
settings for a project and its subprojects:

- `Google Chat URL`: posts the messages of the project to another space
- `Google Chat Thread`: uses another thread for the project; `-` disables its messages, but
  not those of its subprojects

The former names `Hangouts Chat URL` and `Hangouts Chat Thread` still work.

### Threads

| Thread       | One Thread per Issue? | Messages go to                     |
|--------------|-----------------------|------------------------------------|
| *(empty)*    | off                   | a new message each, no thread      |
| `support`    | off                   | the thread `support`               |
| *(empty)*    | on                    | the thread `redmine-issue-<id>`    |
| `support`    | on                    | the thread `support-issue-<id>`    |
| `-`          | any                   | nowhere, messages are disabled     |

Wiki updates never use a thread per issue.

### Ignored fields

List one field per line: the name of a custom field  or of an issue attribute.
Names are matched case-insensitively. Changes of these fields are left out of the messages, 
and updates which only change ignored fields and have no notes are not posted at all.

Attribute names are listed in the journal `details` of `/issues/<id>.json?include=journals`.

## Order approval

Issues whose subject contains `Bestellung` (case-insensitive) show a *Freigeben* button below
the issue details. Clicking it adds the note `ist freigegeben` as the logged-in user. Once
approved, the button is replaced by the approver and date. Anyone allowed to add notes to the
issue can approve it.

Chat messages about orders which are not approved yet get a **FREIGEBEN** button leading to the
approval button in Redmine.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Contributing

Improvements are welcome, just open a pull request.

## Credits

This plugin is maintained by [Cloudogu GmbH](https://cloudogu.com) and builds on two earlier
versions:

- [redmine-slack](https://github.com/sciyoshi/redmine-slack) by Samuel Cormier-Iijima, the
  original plugin which posted Redmine updates to Slack
- [redmine-google-chat](https://github.com/patope/redmine-google-chat) by Tomi Pakarinen, who
  adapted it to Google Chat

Many thanks to both authors for their work, on which this plugin is still based.

## License

MIT, see [LICENSE.md](LICENSE.md).
