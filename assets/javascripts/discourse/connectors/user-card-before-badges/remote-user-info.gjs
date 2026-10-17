import Component from "@glimmer/component";
import { service } from "@ember/service";
import RemoteUserInfo from "../../components/remote-user-info";

// The last outlet on the user card. There is none after the badges, so this is
// as near the bottom as a plugin can place a row.
export default class RemoteUserInfoCardConnector extends Component {
  @service siteSettings;

  get show() {
    return this.siteSettings.remote_user_info_show_on_user_card;
  }

  <template>
    {{#if this.show}}
      <RemoteUserInfo @user={{@outletArgs.user}} @view="card" />
    {{/if}}
  </template>
}
