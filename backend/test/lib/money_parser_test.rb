require "test_helper"

class MoneyParserTest < ActiveSupport::TestCase
  test "parses US formatting with thousands separator" do
    assert_equal [ 129999, "USD" ], MoneyParser.parse("$1,299.99")
  end

  test "parses European comma-decimal formatting" do
    assert_equal [ 129999, "EUR" ], MoneyParser.parse("1.299,99 €")
  end

  test "parses plain decimal" do
    assert_equal [ 129999, "USD" ], MoneyParser.parse("1299.99")
  end

  test "parses a bare comma-decimal amount" do
    assert_equal [ 1299, "EUR" ], MoneyParser.parse("12,99 €")
  end

  test "detects currency by symbol and code" do
    assert_equal [ 500, "GBP" ], MoneyParser.parse("£5.00")
    assert_equal [ 500, "EUR" ], MoneyParser.parse("5.00 EUR")
    assert_equal [ 500, "USD" ], MoneyParser.parse("5.00")
  end

  test "rejects non-price text" do
    assert_nil MoneyParser.parse("Currently unavailable")
    assert_nil MoneyParser.parse("")
    assert_nil MoneyParser.parse(nil)
    assert_nil MoneyParser.parse("Sold out")
  end
end
