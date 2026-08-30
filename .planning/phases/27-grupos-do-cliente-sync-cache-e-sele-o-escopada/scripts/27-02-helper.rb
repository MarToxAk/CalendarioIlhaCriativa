# Runner de verificação do plano 27-02, Task 3 -- não é deliverable da fase,
# é ferramenta de prova para wa_groups_synced_label (helper puro, sem I/O).
h = ApplicationController.helpers
i = WhatsappInstance.new
raise "FAIL: esperava '—' para groups_synced_at ausente" if h.wa_groups_synced_label(i) != "—"

i.groups_synced_at = Time.zone.local(2026, 8, 30, 14, 5)
expected = "30/08/2026 às 14:05"
raise "FAIL: esperava #{expected.inspect}, veio #{h.wa_groups_synced_label(i).inspect}" if h.wa_groups_synced_label(i) != expected

puts "HELPER OK"
