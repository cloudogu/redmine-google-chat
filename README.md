# Redmine Google Chat

A Redmine plugin that posts new issues, issue updates and wiki updates to
[Google Chat](https://workspace.google.com/products/chat/) spaces via incoming webhooks.

## Features

- Messages as Google Chat cards with an **OPEN ISSUE** button
- Every setting can be overridden per project, inherited by subprojects
- Optional one thread per issue
- Ignored fields whose changes are not posted
- Optional order approval with a button in Redmine and in the chat
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
| Order Approval?       | Enables the [order approval](#order-approval)                                    |

### Per project

Every setting can be overridden for a project and its subprojects with a project custom field
(*Administration › Custom fields › Project*). Empty values use the setting of the parent project
or of the plugin.

| Project custom field               | Format    | Overrides                                                |
|------------------------------------|-----------|----------------------------------------------------------|
| `Google Chat URL`                  | Text      | Google Chat URL, to post to another space                |
| `Google Chat Thread`               | Text      | Google Chat Thread; `-` is not inherited by subprojects  |
| `Google Chat One Thread per Issue` | Boolean   | One Thread per Issue?                                    |
| `Google Chat Display Watchers`     | Boolean   | Display Watchers?                                        |
| `Google Chat Post Issue Updates`   | Boolean   | Post Issue Updates?                                      |
| `Google Chat Post Wiki Updates`    | Boolean   | Post Wiki Updates?                                       |
| `Google Chat Ignored Fields`       | Long text | Ignored Fields; replaces the list of the plugin settings |
| `Google Chat Order Approval`       | Boolean   | Order Approval?                                          |

Boolean fields with the edit style *Check box* are never empty: Redmine saves an unchecked box
as "No" when the project is saved. The check box then decides alone, and the setting of the
parent project or of the plugin no longer applies:

| Plugin setting | Project check box | Result |
|----------------|-------------------|--------|
| unchecked      | checked           | on     |
| checked        | checked           | on     |
| unchecked      | unchecked         | off    |
| checked        | unchecked         | off    |

To keep the setting of the parent project or of the plugin for a project, use the edit style
*Drop-down list* or *Radio buttons* and leave the field empty.

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

The order approval is disabled by default. Enable it with *Order Approval?* in the plugin
settings, or per project with the project custom field `Google Chat Order Approval`.

Issues whose subject contains `Bestellung` (case-insensitive) show a *Freigeben* button below
the issue details. Clicking it adds the note `ist freigegeben` as the logged-in user. Once
approved, the button is replaced by the approver and date. Anyone allowed to add notes to the
issue can approve it.

Chat messages about orders which are not approved yet get a **Freigeben** button leading to the
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
