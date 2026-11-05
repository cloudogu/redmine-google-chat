# Google Chat plugin for Redmine

This plugin posts updates to issues in your Redmine installation to a Google Chat
channel. Improvements are welcome! Just send a pull request.

## Installation

From your Redmine plugins directory, clone this repository as `redmine_hangouts_chat` (note
the underscore!):

    git clone https://github.com/cloudogu/redmine-google-chat.git redmine_hangouts_chat

You will also need the `httpclient` dependency, which can be installed by running

    bundle install

from the plugin directory.

Restart Redmine, and you should see the plugin show up in the Plugins page.
Under the configuration options, set the generated Google Chat URL to the URL for an
Incoming WebHook integration in your Google account. (https://developers.google.com/chat/how-tos/webhooks#define_an_incoming_webhook)

## Customized Routing

You can also group messages to threads on a per-project basis. To
do this, create a project custom field (Administration > Custom fields > Project)
named `Google Chat Thread`. If no custom thread is defined for a project, the parent
project will be checked (or the default will be used). Without any thread, every message is
posted on its own. To prevent all notifications from being sent for a project, set the
custom thread to `-`.

To get one thread per issue instead, enable *One Thread per Issue?* in the plugin
configuration. All messages about an issue then go to a thread of its own, which the first
message about the issue starts. The thread is named `<thread>-issue-<id>` after the thread
described above, or `redmine-issue-<id>` if no thread is set. A thread `-` still disables the
messages of a project. Wiki updates stay in the project thread.

## Ignored fields

Changes to some fields can be left out of the update messages. Under the plugin
configuration, list them in *Ignored Fields*, one per line: the name of a custom field
or of an issue attribute. Names are matched case-insensitively. 
An update which only changes ignored fields and has no notes sends no message at all.

## Order approval

Issues whose subject contains `Bestellung` (case-insensitive) show a *Freigeben* button
below the issue details. Clicking it adds the note `ist freigegeben`, authored by the
logged-in user. Once approved, the button is replaced by the approver and date. Anyone
allowed to add notes to the issue can approve it.

For more information, see http://www.redmine.org/projects/redmine/wiki/Plugins.

This is based on redmine slack plugin https://github.com/patope/redmine-google-chat
