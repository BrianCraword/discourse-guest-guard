# name: discourse-guest-guard
# about: Redirect guests to login when visiting protected paths
# version: 0.1.0
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
      return unless SiteSetting.guest_guard_enabled
      return if current_user.present?
      return unless request.get?

      # Allow bypass for support/debug
      if SiteSetting.guest_guard_allow_param && params[:noredirect].present?
        return
      end

      # Parse protected paths from list setting (pipe or comma separated internally)
      raw = SiteSetting.guest_guard_paths.to_s
      patterns =
        if raw.include?("|")
          raw.split("|")
        else
          raw.split(",")
        end.map { |s| s.strip }.reject(&:blank?)

      return if patterns.empty?

      # Normalize request path (ignore query)
      req_path = request.path

      # Match exact or prefix (if ends with '*')
      matched = patterns.any? do |pat|
        if pat.end_with?("*")
          prefix = pat[0..-2]
          req_path.start_with?(prefix)
        else
          req_path == pat
        end
      end

      return unless matched

      # Build login URL (absolute or relative supported)
      login_url = SiteSetting.guest_guard_login_url.presence || "/login"
      begin
        login_uri = URI.parse(login_url)
      rescue
        login_uri = URI.parse("/login")
      end

      # Prevent loops if we're already on the login URL
      login_path = login_uri.path.presence || "/login"
      return if req_path.start_with?(login_path)

      # Optionally preserve destination
      if SiteSetting.guest_guard_preserve_destination
        param_name = SiteSetting.guest_guard_return_param.presence || "redirect_to"
        sep = login_url.include?("?") ? "&" : "?"
        dest = request.fullpath # includes querystring if any
        return redirect_to("#{login_url}#{sep}#{param_name}=#{CGI.escape(dest)}")
      else
        return redirect_to(login_url)
      end
    end
  end
end
