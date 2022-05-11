# Google Chat plugin for Redmine

This plugin posts updates to issues in your Redmine installation to a Google Chat
channel. Improvements are welcome! Just send a pull request.

## Installation

From your Redmine plugins directory, clone this repository as `redmine_hangouts_chat` (note
the underscore!):

    git clone https://github.com/cloudogu/redmine-hangouts-chat.git redmine_hangouts_chat

You will also need the `httpclient` dependency, which can be installed by running

    bundle install

from the plugin directory.

Restart Redmine, and you should see the plugin show up in the Plugins page.
Under the configuration options, set the generated Google Chat URL to the URL for an
Incoming WebHook integration in your Google account.

## Customized Routing

You can also group messages to threads on a per-project basis. To
do this, create a project custom field (Administration > Custom fields > Project)
named `Hangouts Chat Thread`. If no custom thread is defined for a project, the parent
project will be checked (or the default will be used). To prevent all notifications
from being sent for a project, set the custom thread to `-`.

For more information, see http://www.redmine.org/projects/redmine/wiki/Plugins.

This is based on redmine slack plugin https://github.com/patope/redmine-google-chat
