# name: discourse-guest-guard
# about: Redirect guests (and optionally low-TL users) to login when visiting protected paths
# version: 0.2.1
# authors: Brian Crawford
# url: https://community.victoriouschristians.com
# required_version: 3.1.0

enabled_site_setting :guest_guard_enabled

after_initialize do
  require 'uri'
  require 'cgi'

  ApplicationController.class_eval do
    before_action :guest_guard_redirect

    def guest_guard_redirect
      # Toggle + only act on simple GET navigation
      return unless SiteSetting.guest_guard_enabled
      return unless request.get?

      # Don't interfere with API/XHR/JSON requests
      return if request.xhr? || request.format&.json?

      # Optional support/debug bypass
      if SiteSetting.guest_guard_allow_param && params[:noredirect].present?
        return
      end

      # Build protected path list robustly (supports newline, pipe, or comma separators)
      raw = SiteSetting.guest_guard_paths
      parts =
        if raw.respond_to?(:split)
          raw.split(/[\n\|,]/)
        elsif raw.respond_to?(:to_a)
          raw.to_a
        else
          [raw.to_s]
        end

      patterns = parts.map { |s| s.to_s.strip }.reject(&:blank?)
      return if patterns.empty?

      req_path = request.path

      # Match exact or prefix when pattern ends with '*'
      protected_hit = patterns.any? do |pat|
        if pat.end_with?('*')
          req_path.start_with?(pat[0..-2])
        else
          req_path == pat
        end
      end
      return unless protected_hit

      # Determine viewer state (canonical guest check)
      is_guest = (guardian.respond_to?(:anonymous?) ? guardian.anonymous? : current_user.nil?)

      # Optional TL gate: if configured, redirect users with TL < min
      min_tl = SiteSetting.guest_guard_min_trust_level.to_i
      if !is_guest
        if min_tl >= 0
          user_tl = current_user&.trust_level.to_i
          return if user_tl >= min_tl
        else
          # Logged-in and no TL rule -> allow
          return
        end
      end

      # Build login URL (absolute or relative supported)
      login_url = SiteSetting.guest_guard_login_url.presence || "/login"

      # Avoid loops if already on login path (for relative URLs)
      login_path_only =
        begin
          URI.parse(login_url).path.presence || "/login"
        rescue
          "/login"
        end

      # If current request path already is the login path, don't redirect
      return if req_path.start_with?(login_path_only)

      if SiteSetting.guest_guard_preserve_destination
        param = SiteSetting.guest_guard_return_param.presence || "redirect_to"
        sep   = login_url.include?("?") ? "&" : "?"
        dest  = request.fullpath # keep querystring
        redirect_to "#{login_url}#{sep}#{param}=#{CGI.escape(dest)}"
      else
        redirect_to login_url
      end
    end
  end
end
