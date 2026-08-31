require "test_helper"

class SolidQueueRetentionTest < ActiveSupport::TestCase
  test "failed_execution_days cai no fallback 14 sem env var" do
    original = ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"]
    ENV.delete("SOLID_QUEUE_FAILED_RETENTION_DAYS")

    assert_equal 14, SolidQueueRetention.failed_execution_days
  ensure
    ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"] = original
  end

  test "failed_execution_days le SOLID_QUEUE_FAILED_RETENTION_DAYS quando presente" do
    original = ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"]
    ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"] = "30"

    assert_equal 30, SolidQueueRetention.failed_execution_days
  ensure
    ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"] = original
  end

  test "failed_execution_days levanta ArgumentError com valor invalido (WR-01 -- fail-fast)" do
    original = ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"]
    ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"] = "14d"

    assert_raises(ArgumentError) { SolidQueueRetention.failed_execution_days }
  ensure
    ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"] = original
  end

  test "config/recurring.yml chama SolidQueueRetention.failed_execution_days em vez de Integer(ENV.fetch(...)) inline" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))

    %w[production development].each do |env|
      command = config.dig(env, "prune_solid_queue_failed_executions", "command")
      assert_includes command, "SolidQueueRetention.failed_execution_days"
      refute_includes command, "ENV.fetch(\"SOLID_QUEUE_FAILED_RETENTION_DAYS\""
    end
  end
end
