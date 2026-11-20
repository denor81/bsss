# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

I18N_MESSAGES["dns.status.protected_google_cloudflare"]="DNS is protected: strict DoT, Google + Cloudflare"
I18N_MESSAGES["dns.status.protected_yandex_google"]="DNS is protected: strict DoT, Yandex + Google"
I18N_MESSAGES["dns.status.unconfirmed"]="DNS protection is not confirmed"
I18N_MESSAGES["dns.value.unset"]="not configured"

I18N_MESSAGES["dns.issue.missing_command"]="Required command is unavailable: %s"
I18N_MESSAGES["dns.issue.unsupported_os"]="DNS module does not support this operating system: %s"
I18N_MESSAGES["dns.issue.resolved_inactive"]="systemd-resolved is not active"
I18N_MESSAGES["dns.issue.resolv_conf"]="/etc/resolv.conf does not use the standard systemd-resolved stub: %s"
I18N_MESSAGES["dns.issue.stub_inactive"]="The systemd-resolved stub is not listening on 127.0.0.53:53"
I18N_MESSAGES["dns.issue.effective_unavailable"]="Effective systemd-resolved configuration could not be determined"
I18N_MESSAGES["dns.issue.profile_unknown"]="The active DNS profile is not recognized: %s"
I18N_MESSAGES["dns.issue.fallback_dns"]="FallbackDNS is not disabled: %s"
I18N_MESSAGES["dns.issue.domains"]="The global DNS root route is not exclusive: %s"
I18N_MESSAGES["dns.issue.dot_mode"]="Strict DNS-over-TLS is not enabled: %s"
I18N_MESSAGES["dns.issue.dnssec"]="The supported DNSSEC mode is not active: %s"
I18N_MESSAGES["dns.issue.llmnr"]="LLMNR is not disabled: %s"
I18N_MESSAGES["dns.issue.multicast_dns"]="MulticastDNS is not disabled: %s"
I18N_MESSAGES["dns.issue.route_domain"]="Link %s has a separate DNS route: %s"
I18N_MESSAGES["dns.issue.runtime_unavailable"]="Runtime DNS routes could not be determined"
I18N_MESSAGES["dns.issue.unknown"]="Unknown DNS state issue: %s"
