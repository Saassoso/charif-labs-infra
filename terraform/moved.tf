# --- Blocs de migration d'état v4 -> v5 ---
moved {
  from = cloudflare_record.tunnel_cnames
  to   = cloudflare_dns_record.tunnel_cnames
}
moved {
  from = cloudflare_record.microsoft_verification
  to   = cloudflare_dns_record.microsoft_verification
}
moved {
  from = cloudflare_record.google_site_verification
  to   = cloudflare_dns_record.google_site_verification
}
moved {
  from = cloudflare_record.mgmt_dns
  to   = cloudflare_dns_record.mgmt_dns
}