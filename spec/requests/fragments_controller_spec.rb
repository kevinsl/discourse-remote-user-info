# frozen_string_literal: true

require "rails_helper"

describe DiscourseRemoteUserInfo::FragmentsController do
  fab!(:user)

  before do
    SiteSetting.remote_user_info_enabled = true
    SiteSetting.remote_user_info_card_url = "https://example.com/card/%{username}"
    SiteSetting.remote_user_info_summary_url = "https://example.com/summary/%{username}"
    Discourse.cache.clear
  end

  def stub_source(body:, status: 200, content_type: "text/html")
    stub_request(:get, %r{https://example\.com/}).to_return(
      status: status,
      body: body,
      headers: {
        "Content-Type" => content_type,
      },
    )
  end

  describe "#show" do
    it "returns the sanitised fragment" do
      stub_source(body: '<div class="card-row"><span class="desc">x</span></div>')

      get "/remote-user-info/#{user.username}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["html"]).to include("card-row")
    end

    it "is no content when the source has nothing for this user" do
      stub_source(body: "", status: 204)

      get "/remote-user-info/#{user.username}.json"

      expect(response.status).to eq(204)
    end

    it "is no content for a user that does not exist, without saying so" do
      get "/remote-user-info/nobody-at-all.json"

      expect(response.status).to eq(204)
    end

    it "is no content when the source is unreachable" do
      stub_request(:get, %r{https://example\.com/}).to_timeout

      get "/remote-user-info/#{user.username}.json"

      expect(response.status).to eq(204)
    end

    it "does nothing when no url is configured for that view" do
      SiteSetting.remote_user_info_card_url = ""

      get "/remote-user-info/#{user.username}.json"

      expect(response.status).to eq(204)
    end

    it "is disabled with the plugin" do
      SiteSetting.remote_user_info_enabled = false

      get "/remote-user-info/#{user.username}.json"

      expect(response.status).to eq(404)
    end

    context "with hostile markup" do
      it "strips scripts and event handlers" do
        stub_source(
          body:
            '<div class="card-row"><script>alert(1)</script><a href="#" onclick="alert(2)">x</a></div>',
        )

        get "/remote-user-info/#{user.username}.json"

        html = response.parsed_body["html"]
        expect(html).not_to include("script")
        expect(html).not_to include("alert(1)")
        expect(html).not_to include("onclick")
      end

      it "strips inline styles, so the fragment cannot fight the theme" do
        stub_source(body: '<div class="card-row" style="position:fixed;top:0">x</div>')

        get "/remote-user-info/#{user.username}.json"

        html = response.parsed_body["html"]
        expect(html).not_to include("style")
        expect(html).to include("card-row")
      end

      it "strips javascript: links" do
        stub_source(body: '<a href="javascript:alert(1)">x</a>')

        get "/remote-user-info/#{user.username}.json"

        expect(response.parsed_body["html"]).not_to include("javascript:")
      end

      it "refuses a response that is too large to be a row" do
        stub_source(body: "<div>#{"x" * 40_000}</div>")

        get "/remote-user-info/#{user.username}.json"

        expect(response.status).to eq(204)
      end
    end

    context "with two urls" do
      it "fetches the card url for the card view" do
        stub_source(body: "<div>ok</div>")

        get "/remote-user-info/#{user.username}.json", params: { view: "card" }

        expect(WebMock).to have_requested(:get, %r{example\.com/card/})
      end

      it "fetches the summary url for the summary view" do
        stub_source(body: "<div>ok</div>")

        get "/remote-user-info/#{user.username}.json", params: { view: "summary" }

        expect(WebMock).to have_requested(:get, %r{example\.com/summary/})
      end

      it "falls back to the card view for anything unrecognised" do
        stub_source(body: "<div>ok</div>")

        get "/remote-user-info/#{user.username}.json", params: { view: "../../etc" }

        expect(WebMock).to have_requested(:get, %r{example\.com/card/})
      end

      it "leaves one surface off when only the other has a url" do
        SiteSetting.remote_user_info_summary_url = ""
        stub_source(body: "<div>ok</div>")

        get "/remote-user-info/#{user.username}.json", params: { view: "summary" }
        expect(response.status).to eq(204)

        get "/remote-user-info/#{user.username}.json", params: { view: "card" }
        expect(response.status).to eq(200)
      end

      it "caches each view separately" do
        stub_source(body: "<div>ok</div>")

        get "/remote-user-info/#{user.username}.json", params: { view: "card" }
        get "/remote-user-info/#{user.username}.json", params: { view: "summary" }

        expect(WebMock).to have_requested(:get, %r{example\.com/card/}).once
        expect(WebMock).to have_requested(:get, %r{example\.com/summary/}).once
      end

      it "stops serving the old source when the url changes" do
        stub_request(:get, %r{example\.com/card/}).to_return(status: 200, body: "<div>old</div>")
        get "/remote-user-info/#{user.username}.json"
        expect(response.parsed_body["html"]).to include("old")

        SiteSetting.remote_user_info_card_url = "https://example.com/other/%{username}"
        stub_request(:get, %r{example\.com/other/}).to_return(status: 200, body: "<div>new</div>")

        get "/remote-user-info/#{user.username}.json"
        expect(response.parsed_body["html"]).to include("new")
      end
    end

    it "does not answer a plain browser request" do
      stub_source(body: "<div>ok</div>")

      get "/remote-user-info/#{user.username}"

      expect(response.body).to be_blank
      expect(WebMock).not_to have_requested(:get, %r{example\.com/})
    end

    it "caches, so a popover does not hammer the source" do
      stub_source(body: "<div>ok</div>")

      2.times { get "/remote-user-info/#{user.username}.json" }

      expect(WebMock).to have_requested(:get, %r{example\.com/card/}).once
    end
  end
end
