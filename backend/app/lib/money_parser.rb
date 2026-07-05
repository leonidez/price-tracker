require "bigdecimal"

# Parse a human price string into integer cents + a currency code.
#
#   MoneyParser.parse("$1,299.99") # => [129999, "USD"]
#   MoneyParser.parse("1.299,99 €") # => [129999, "EUR"]
#   MoneyParser.parse("Sold out")   # => nil
module MoneyParser
  module_function

  SYMBOL_CURRENCIES = { "$" => "USD", "€" => "EUR", "£" => "GBP" }.freeze
  CODE_CURRENCIES = %w[USD EUR GBP].freeze

  def parse(text)
    string = text.to_s
    return nil unless string.match?(/\d/)

    number = normalize_number(string.scan(/[\d.,]/).join)
    return nil if number.nil? || number.empty?

    cents = (BigDecimal(number) * 100).round
    [ cents, detect_currency(string) ]
  rescue ArgumentError
    nil
  end

  def detect_currency(string)
    SYMBOL_CURRENCIES.each { |symbol, code| return code if string.include?(symbol) }
    CODE_CURRENCIES.each { |code| return code if string.upcase.include?(code) }
    "USD"
  end

  # Collapse thousands separators and normalize the decimal separator to ".".
  def normalize_number(raw)
    has_comma = raw.include?(",")
    has_dot = raw.include?(".")

    if has_comma && has_dot
      # The rightmost separator is the decimal point.
      if raw.rindex(",") > raw.rindex(".")
        raw.delete(".").tr(",", ".")
      else
        raw.delete(",")
      end
    elsif has_comma
      # A single comma followed by 1-2 digits is a decimal comma (e.g. "12,99").
      raw.match?(/,\d{1,2}\z/) ? raw.tr(",", ".") : raw.delete(",")
    else
      raw
    end
  end
end
