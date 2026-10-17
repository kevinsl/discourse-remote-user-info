import Component from "@glimmer/component";
import { service } from "@ember/service";
import RemoteUserInfo from "../../components/remote-user-info";

export default class RemoteUserInfoSummaryConnector extends Component {
  @service siteSettings;

  get show() {
    return this.siteSettings.remote_user_info_show_on_user_summary;
  }

  <template>
    {{#if this.show}}
      <RemoteUserInfo @user={{@outletArgs.user}} @view="summary" />
    {{/if}}
  </template>
}
