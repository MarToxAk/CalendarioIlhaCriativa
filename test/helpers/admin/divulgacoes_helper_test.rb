require "test_helper"

class Admin::DivulgacoesHelperTest < ActionView::TestCase
  test "divulgacao_datetime_label(nil) retorna o travessao" do
    assert_equal "—", divulgacao_datetime_label(nil)
  end

  test "divulgacao_datetime_label('') retorna o travessao" do
    assert_equal "—", divulgacao_datetime_label("")
  end

  test "divulgacao_datetime_label formata DD/MM/AAAA HH:MM (BRT)" do
    t = Time.zone.local(2025, 9, 15, 14, 0)
    assert_equal "15/09/2025 14:00 (BRT)", divulgacao_datetime_label(t)
  end
end
