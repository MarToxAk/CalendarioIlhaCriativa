ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load .env before database.yml is evaluated so POSTGRES_PASSWORD is available.
require "dotenv/load" if File.exist?(File.expand_path("../../.env", __FILE__))
