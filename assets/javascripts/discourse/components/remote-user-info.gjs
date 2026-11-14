import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";

// Fetches a fragment for one user and renders it.
//
// The markup comes from the remote system and is inserted as-is, which is the
// whole design: the fragment uses Discourse's own class names, so it inherits
// the theme — light, dark and any custom colour scheme — without this plugin
// shipping a stylesheet for it. The server has already run it through an
// allowlist; nothing is trusted here that was not sanitised there.
//
// Renders nothing at all until there is something to show, so a user with no
// record in the remote system leaves no empty row behind.
//
// Discourse keeps this component when you move from one user's page (or card)
// to another's and only changes @user, so fetching once in the constructor
// showed the first user's fragment on every user after. It fetches whenever the
// username changes instead, and only shows a fragment fetched for the user now
// on screen.
export default class RemoteUserInfo extends Component {
  @service siteSettings;

  // { username, html } for the last fragment that came back
  @tracked loaded = null;

  // the username last asked for; not tracked, it is only bookkeeping
  requested = null;

  // Called from the template with the current username, so it runs again
  // whenever that changes. Starts a fetch and returns nothing to render.
  fetchFor = (username) => {
    if (!this.siteSettings.remote_user_info_enabled || !username) {
      return;
    }
    if (username === this.requested) {
      return;
    }
    this.requested = username;
    this.load(username);
  };

  get username() {
    return this.args.user?.username;
  }

  get html() {
    return this.loaded?.username === this.username ? this.loaded.html : null;
  }

  async load(username) {
    let html = null;
    try {
      const response = await ajax(
        `/remote-user-info/${encodeURIComponent(username)}.json`,
        { data: { view: this.args.view ?? "card" } }
      );
      html = response?.html ?? null;
    } catch {
      // A remote system that is down or slow should cost the user nothing.
      // The server already logs the cause; here it is simply absent.
    }

    // The user may have moved on while this was in flight.
    if (this.isDestroying || this.isDestroyed || this.requested !== username) {
      return;
    }
    this.loaded = { username, html };
  }

  <template>
    {{this.fetchFor this.username}}
    {{#if this.html}}
      {{htmlSafe this.html}}
    {{/if}}
  </template>
}
