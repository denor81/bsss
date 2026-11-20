# BSSS: Basic Server Security Setup
# Part of the BSSS project (https://github.com/denor81/bsss)
# Licensed under MIT

I18N_MESSAGES["dns.status.protected_google_cloudflare"]="DNS защищён: строгий DoT, Google + Cloudflare"
I18N_MESSAGES["dns.status.protected_yandex_google"]="DNS защищён: строгий DoT, Yandex + Google"
I18N_MESSAGES["dns.status.unconfirmed"]="Защита DNS не подтверждена"
I18N_MESSAGES["dns.value.unset"]="не настроено"

I18N_MESSAGES["dns.issue.missing_command"]="Недоступна обязательная команда: %s"
I18N_MESSAGES["dns.issue.unsupported_os"]="DNS-модуль не поддерживает эту операционную систему: %s"
I18N_MESSAGES["dns.issue.resolved_inactive"]="systemd-resolved не активен"
I18N_MESSAGES["dns.issue.resolv_conf"]="/etc/resolv.conf не использует стандартный stub systemd-resolved: %s"
I18N_MESSAGES["dns.issue.stub_inactive"]="Stub systemd-resolved не слушает 127.0.0.53:53"
I18N_MESSAGES["dns.issue.effective_unavailable"]="Не удалось определить эффективную конфигурацию systemd-resolved"
I18N_MESSAGES["dns.issue.profile_unknown"]="Активный DNS-профиль не распознан: %s"
I18N_MESSAGES["dns.issue.fallback_dns"]="FallbackDNS не отключён: %s"
I18N_MESSAGES["dns.issue.domains"]="Глобальный корневой DNS-маршрут не является исключительным: %s"
I18N_MESSAGES["dns.issue.dot_mode"]="Строгий DNS-over-TLS не включён: %s"
I18N_MESSAGES["dns.issue.dnssec"]="Не активен поддерживаемый режим DNSSEC: %s"
I18N_MESSAGES["dns.issue.llmnr"]="LLMNR не отключён: %s"
I18N_MESSAGES["dns.issue.multicast_dns"]="MulticastDNS не отключён: %s"
I18N_MESSAGES["dns.issue.route_domain"]="Интерфейс %s имеет отдельный DNS-маршрут: %s"
I18N_MESSAGES["dns.issue.runtime_unavailable"]="Не удалось определить runtime DNS-маршруты"
I18N_MESSAGES["dns.issue.unknown"]="Неизвестная проблема состояния DNS: %s"
