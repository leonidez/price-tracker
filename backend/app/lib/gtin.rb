# Barcode normalization and GS1 checksum validation.
#
# All barcodes are stored as 13-digit GTIN-13 strings (see docs/DESIGN.md).
# Scanners report UPC-A (12 digits), EAN-13 (13 digits), or UPC-E (8 digits).
module Gtin
  module_function

  # Normalize a raw scanned code to a 13-digit GTIN string, or nil if it is not
  # a recognizable / valid barcode.
  #
  #   symbology: :upc_e is required to expand the 8-digit UPC-E form the scanner
  #   reports; other 8-digit inputs are rejected.
  def normalize(raw, symbology: nil)
    digits = raw.to_s.gsub(/\D/, "")

    gtin13 =
      case digits.length
      when 13 then digits
      when 12 then "0#{digits}"
      when 8
        upc_a = expand_upc_e(digits) if symbology.to_s == "upc_e"
        upc_a && "0#{upc_a}"
      end

    return nil if gtin13.nil?

    valid?(gtin13) ? gtin13 : nil
  end

  # GS1 mod-10 checksum over a 13-digit string.
  def valid?(gtin13)
    return false unless gtin13.to_s.match?(/\A\d{13}\z/)

    digits = gtin13.chars.map(&:to_i)
    check = digits.pop
    check == check_digit(digits)
  end

  # Compute the mod-10 check digit for the leading 12 data digits.
  def check_digit(data_digits)
    sum = data_digits.reverse.each_with_index.sum do |digit, index|
      index.even? ? digit * 3 : digit
    end
    (10 - (sum % 10)) % 10
  end

  # Expand an 8-digit UPC-E code (number system + 6 data + check) to a 12-digit
  # UPC-A using the standard GS1 expansion, keyed on the 6th data digit.
  def expand_upc_e(digits)
    return nil unless digits.length == 8

    ns = digits[0]
    d = digits[1, 6].chars
    check = digits[7]
    manufacturer_and_item =
      case d[5]
      when "0", "1", "2"
        [ d[0], d[1], d[5], "0", "0", "0", "0", d[2], d[3], d[4] ]
      when "3"
        [ d[0], d[1], d[2], "0", "0", "0", "0", "0", d[3], d[4] ]
      when "4"
        [ d[0], d[1], d[2], d[3], "0", "0", "0", "0", "0", d[4] ]
      else # 5..9
        [ d[0], d[1], d[2], d[3], d[4], "0", "0", "0", "0", d[5] ]
      end

    "#{ns}#{manufacturer_and_item.join}#{check}"
  end
end
