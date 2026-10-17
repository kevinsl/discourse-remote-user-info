import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import { service } from "@ember/service";
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
export default class RemoteUserInfo extends Component {
  @service siteSettings;

  @tracked html = null;

  constructor() {
    super(...arguments);
    this.load();
  }

  get username() {
    return this.args.user?.username;
  }

  async load() {
    if (!this.siteSettings.remote_user_info_enabled || !this.username) {
      return;
    }

    try {
      const response = await ajax(
        `/remote-user-info/${encodeURIComponent(this.username)}.json`,
        { data: { view: this.args.view ?? "card" } }
      );
      this.html = response?.html ?? null;
    } catch {
      // A remote system that is down or slow should cost the user nothing.
      // The server already logs the cause; here it is simply absent.
      this.html = null;
    }
  }

  <template>
    {{#if this.html}}
      {{htmlSafe this.html}}
    {{/if}}
  </template>
}
