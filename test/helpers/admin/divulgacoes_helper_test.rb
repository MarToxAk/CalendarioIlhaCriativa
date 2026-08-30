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

  # --- divulgacao_duration_estimate (DIVU-07) ---------------------------

  test "divulgacao_duration_estimate(0) retorna o travessao (zero-state)" do
    assert_equal "—", divulgacao_duration_estimate(0, min: 25, max: 45)
  end

  test "divulgacao_duration_estimate(20, 25, 45) retorna a faixa humana" do
    assert_equal "≈ 9–15 min para 20 grupos", divulgacao_duration_estimate(20, min: 25, max: 45)
  end

  test "divulgacao_duration_estimate(1, 25, 45) colapsa lo==hi num valor unico" do
    assert_equal "≈ 1 min para 1 grupos", divulgacao_duration_estimate(1, min: 25, max: 45)
  end

  test "divulgacao_duration_estimate usa Divulgacao::SEND_DELAY_MIN/MAX como default" do
    lo = (3 * Divulgacao::SEND_DELAY_MIN / 60.0).ceil
    hi = (3 * Divulgacao::SEND_DELAY_MAX / 60.0).ceil
    esperado = lo == hi ? "≈ #{lo} min para 3 grupos" : "≈ #{lo}–#{hi} min para 3 grupos"
    assert_equal esperado, divulgacao_duration_estimate(3)
  end

  test "Divulgacao::SEND_DELAY_MIN/MAX caem no fallback 25/45 sem env var" do
    assert_equal 25, Divulgacao::SEND_DELAY_MIN
    assert_equal 45, Divulgacao::SEND_DELAY_MAX
  end
end
