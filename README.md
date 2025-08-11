# Discourse Guest Guard

Redirect **guests** to your login page when they try to access protected URLs (e.g., your AI Conversations page), instead of showing Discourse’s “page not found”.

- Works only for **anonymous users**
- Fully configurable in **Admin → Settings → Plugins**
- Lightweight and compatible with other plugins (e.g., your logged-in homepage redirect)

---

## What it does

For GET requests from **not-logged-in** users, if the requested path matches any **protected path**, the request is **redirected to your login URL** (e.g. `/login` or `https://community.victoriouschristians.com/login`).  
Optionally, the plugin can append the original destination (e.g. `?redirect_to=/discourse-ai/ai-bot/conversations`) so your auth flow can send users back after login.

---

## Requirements

- Discourse **3.1.0+**
- Official Docker install or equivalent production image

---

## Installation

Add to your container (`/var/discourse/containers/app.yml`):

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/BrianCraword/discourse-guest-guard.git
Then rebuild:

bash
Copy code
cd /var/discourse
./launcher rebuild app
Configuration
Admin → Settings → Plugins → search for “guest guard”.

Setting	Purpose	Example / Default
guest_guard_enabled	Master on/off toggle	true
guest_guard_paths	Protected paths (list). Exact match or prefix with *	/discourse-ai/ai-bot/conversations, /my/*
guest_guard_login_url	Where guests are sent (relative or absolute)	/login or https://community.victoriouschristians.com/login
guest_guard_preserve_destination	Append original path to login URL as query param	false
guest_guard_return_param	Name of param used when preserving destination	redirect_to
guest_guard_allow_param	Adds a support bypass (?noredirect=1)	true

Examples
Protect a single page

bash
Copy code
/discourse-ai/ai-bot/conversations
Protect a section

bash
Copy code
/my/*
/g/ai_premium/*
Absolute login URL

arduino
Copy code
https://community.victoriouschristians.com/login
Preserve destination

Enabled → visiting /discourse-ai/ai-bot/conversations as guest redirects to
/login?redirect_to=/discourse-ai/ai-bot/conversations

How it works
The plugin adds a small before_action to ApplicationController that:

Runs only for guests and GET requests.

Checks the request path against your configured list (exact or prefix*).

Redirects to the configured login URL (optionally appending the original destination).

Skips redirect if the request is already on the login URL (prevents loops) or ?noredirect=1 is present.

Testing
Logged out, visit a protected path (e.g. /discourse-ai/ai-bot/conversations) → you should land on the login page.

Add ?noredirect=1 to a protected URL → you should see the original page (useful for support).

Logged in, visit the same path → plugin does nothing.

Compatibility notes
Designed to coexist with “homepage redirect” plugins (those act on logged-in users; this acts on guests).

Only intercepts GET; other HTTP verbs are ignored.

Use relative /login or absolute login URL—both work.

Troubleshooting
No redirect? Check:

guest_guard_enabled is true

The path is listed exactly (or with * suffix for prefixes)

You’re testing while logged out

