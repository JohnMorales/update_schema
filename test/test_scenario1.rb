require 'minitest/autorun'

class SunnyDayTests < Minitest::Unit::TestCase
  def setup
    result = `./update_schema.rb test/schema_scenario1/setup.sql`
    raise result if $?.exitstatus > 0
    puts result
  end
  def test_creating_schema
    result = `./update_schema.rb test/schema_scenario1/`
    assert_equal "Applied 001-contacts.sql.", result.strip
  end
end
