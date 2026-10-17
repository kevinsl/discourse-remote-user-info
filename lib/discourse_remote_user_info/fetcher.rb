# frozen_string_literal: true

module ::DiscourseRemoteUserInfo
  # Fetches an HTML fragment about one user from a remote system, sanitises it,
  # and caches the result.
  #
  # The fragment is rendered into the page as trusted HTML, so everything that
  # matters happens here rather than in the browser:
  #
  #   * the request goes out through FinalDestination::HTTP, which resolves and
  #     filters addresses before connecting. The URL is set by an admin, so
  #     without this the plugin is an SSRF primitive pointed at the forum's own
  #     network.
  #   * the response is run through an allowlist that permits structure and
  #     strips everything else. Dropping "style" is not only an XSS measure: it
  #     is what forces the fragment to inherit the forum's own CSS rather than
  #     bring its own, which is the point of serving HTML at all.
  #   * results are cached, because user cards open constantly.
  class Fetcher
    # Structure only. No img, no iframe, no style, no script, no id — an id
    # could collide with the host page, and everything else here is either an
    # injection vector or a way to smuggle in styling.
    ALLOWED_TAGS = %w[div span a p ul ol li strong em b i br small].freeze
    ALLOWED_ATTRIBUTES = { "a" => %w[href title], :all => %w[class title] }.freeze
    ALLOWED_PROTOCOLS = { "a" => { "href" => %w[http https] } }.freeze

    # A fragment is a row in a popover. Anything larger is a misconfiguration,
    # and reading it into memory is the attacker's cheapest move.
    MAX_BYTES = 32_768

    class << self
      def fragment(username, view)
        return nil if username.blank?
        return nil if %w[card summary].exclude?(view)

        url = build_url(username, view)
        return nil if url.blank?

        Discourse
          .cache
          .fetch(cache_key(username, view), expires_in: cache_duration) { fetch_and_sanitize(url) }
      end

      private

      # Each surface has its own URL. They want different markup — the card is a
      # cramped popover, the summary has room — and a source is as likely to
      # serve those from two paths as from one with a parameter. Leaving a view
      # unset is how you turn that surface off at the source.
      def url_setting(view)
        case view
        when "card"
          SiteSetting.remote_user_info_card_url
        when "summary"
          SiteSetting.remote_user_info_summary_url
        end
      end

      def build_url(username, view)
        template = url_setting(view).to_s.strip
        return nil if template.blank?

        # Deliberately not format/%: the template is admin-supplied and may
        # legitimately contain a bare % (an already-encoded path, say), which
        # would raise.
        template.gsub("%{username}", CGI.escape(username.to_s))
      end

      def fetch_and_sanitize(url)
        body = get(url)
        return nil if body.blank?

        html = sanitize(body)
        html.presence
      end

      def get(url)
        uri = URI.parse(url)
        return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

        timeout = timeout_seconds
        http = FinalDestination::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = timeout
        http.read_timeout = timeout

        response = http.start { |h| h.request(Net::HTTP::Get.new(uri.request_uri, headers)) }

        # 204 is the documented way for a source to say "nothing for this user",
        # so it is a normal answer rather than a failure.
        return nil unless response.is_a?(Net::HTTPOK)

        body = response.body.to_s
        return nil if body.bytesize > MAX_BYTES

        body
      rescue StandardError => e
        # A slow or broken source must never take the user card with it.
        Rails.logger.warn("#{PLUGIN_NAME}: fetch failed for #{url}: #{e.class}: #{e.message}")
        nil
      end

      def headers
        {
          "Accept" => "text/html",
          "User-Agent" => "Discourse/#{Discourse::VERSION::STRING} #{PLUGIN_NAME}",
        }
      end

      def sanitize(body)
        Sanitize.fragment(
          body,
          elements: ALLOWED_TAGS,
          attributes: ALLOWED_ATTRIBUTES,
          protocols: ALLOWED_PROTOCOLS,
          remove_contents: %w[script style],
        ).strip
      end

      def timeout_seconds
        [SiteSetting.remote_user_info_timeout_ms.to_i, 250].max / 1000.0
      end

      def cache_duration
        # A floor, so a misconfigured zero cannot turn every hover into a
        # request against the remote system.
        [SiteSetting.remote_user_info_cache_minutes.to_i, 1].max.minutes
      end

      # Keyed on the URL as well as the user, so changing a setting takes effect
      # immediately instead of serving the old source until the cache expires.
      def cache_key(username, view)
        digest = Digest::SHA1.hexdigest(url_setting(view).to_s)
        "#{PLUGIN_NAME}:#{digest}:#{view}:#{username.downcase}"
      end
    end
  end
end
