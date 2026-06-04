require "test_helper"

class BrazilianHolidaysTest < ActiveSupport::TestCase
  test "retorna hash para ano coberto 2026" do
    result = BrazilianHolidays.for(2026)
    assert_instance_of Hash, result
    assert result.any?
  end

  test "retorna hash vazio para ano sem cobertura" do
    result = BrazilianHolidays.for(9999)
    assert_equal({}, result)
  end

  test "Ano Novo 2026 está presente" do
    holidays = BrazilianHolidays.for(2026)
    assert_equal "Ano Novo", holidays[Date.new(2026, 1, 1)]
  end

  test "Corpus Christi 2026 está em 04/06" do
    holidays = BrazilianHolidays.for(2026)
    assert_equal "Corpus Christi", holidays[Date.new(2026, 6, 4)]
  end

  test "Black Friday 2026 está em 27/11" do
    holidays = BrazilianHolidays.for(2026)
    assert_equal "Black Friday", holidays[Date.new(2026, 11, 27)]
  end

  test "Dia das Mães 2025 está em 11/05" do
    holidays = BrazilianHolidays.for(2025)
    assert_equal "Dia das Mães", holidays[Date.new(2025, 5, 11)]
  end

  test "data sem feriado retorna nil" do
    holidays = BrazilianHolidays.for(2026)
    assert_nil holidays[Date.new(2026, 3, 10)]
  end

  test "cobre os três anos configurados" do
    [2025, 2026, 2027].each do |year|
      assert BrazilianHolidays.for(year).any?, "Ano #{year} deve ter feriados"
    end
  end
end
