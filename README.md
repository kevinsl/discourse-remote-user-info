# discourse-remote-user-info

Shows a row of information about a user, fetched from another system, on the
Discourse user card and profile summary.

The remote system returns a small **HTML fragment** rather than JSON. That is
the whole idea: the fragment uses Discourse's own class names, so it inherits
the forum's theme — light, dark, custom colour schemes — and you can change
what it shows without touching or redeploying this plugin.

## How it works

```
user card  ──▶  your forum  ──▶  fetch {remote_user_info_card_url}
                                 sanitise against an allowlist
                                 cache
                 ◀──────────────  render as trusted HTML
```

The browser never talks to the remote system directly, which is what lets the
fragment be sanitised, cached, and fetched without CORS.

Nothing here is part of the contract your endpoint implements — you point a
setting at a URL and return a fragment. The rest is the plugin's business.

## Settings

| setting | default | |
|---|---|---|
| `remote_user_info_enabled` | `false` | |
| `remote_user_info_card_url` | `""` | fragment for the user card; `%{username}` is substituted |
| `remote_user_info_summary_url` | `""` | fragment for the profile summary; leave blank to show nothing there |
| `remote_user_info_show_on_user_card` | `true` | |
| `remote_user_info_show_on_user_summary` | `true` | |
| `remote_user_info_cache_minutes` | `10` | minimum 1 |
| `remote_user_info_timeout_ms` | `2000` | |

Example:

```
remote_user_info_card_url     https://example.com/api/usercard/%{username}?view=card
remote_user_info_summary_url  https://example.com/api/usercard/%{username}?view=summary
```

The two surfaces want different markup — the card is a cramped popover, the
summary has room — so they get their own URLs. Serve them from one endpoint
with a parameter, as above, or from two separate paths; the plugin does not
care. Leaving one blank turns that surface off.

## What your endpoint should return

`200` with an HTML fragment, or **`204` when there is nothing to show** for that
user — then no row is rendered at all, rather than an empty one.

To inherit the forum's styling, use Discourse's own classes and ship no CSS:

**The card**

```html
<div class="card-row">
  <div class="metadata">
    <div class="metadata__yours"><span class="desc">Label</span> value</div>
  </div>
</div>
```

**The summary** — matching core's own stat markup makes your stats
indistinguishable from the built-in ones:

```html
<li class="linked-stat">
  <a href="https://example.com/u/alice">
    <div class="user-stat">
      <span class="value">341</span>
      <span class="label">In collection</span>
    </div>
  </a>
</li>
```

### What is stripped

The response is run through an allowlist before it reaches a browser.

**Kept:** `div span a p ul ol li strong em b i br small`, and the attributes
`class`, `title`, and `href` on links (`http` and `https` only).

**Removed:** `<script>`, `<style>`, `style=`, `id=`, every `on*` handler,
`<img>`, `<iframe>`, and anything else not listed.

Dropping `style` is not only a safety measure — it is what forces the fragment
to inherit the forum's CSS instead of bringing its own.

Responses over 32 KB are rejected. A row in a popover is not that large, and
reading an unbounded body into memory is the cheapest attack available.

## Security

The URL is admin-configurable and the **server** fetches it, which is an SSRF
primitive if handled carelessly. Requests go through Discourse's
`FinalDestination::HTTP`, which resolves and filters addresses before
connecting — the same path core uses for its own outbound fetches.

Two things to understand before pointing this at a source you do not control:

* a fragment using Discourse's class names can *look* like native forum UI
* whatever the source returns is shown to anyone who can see that user's card

## Installation

Add to `containers/app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/kevinsl/discourse-remote-user-info.git
```

Then `cd /var/discourse && ./launcher rebuild app`. Later updates can go
through `/admin/upgrade` without a rebuild.

## Licence

MIT
