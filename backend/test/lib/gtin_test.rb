require "test_helper"

class GtinTest < ActiveSupport::TestCase
  # --- checksum (3 fixed, hand-computed examples) ---
  test "valid? accepts correct GS1 check digits" do
    assert Gtin.valid?("4006381333931")   # EAN-13, check 1
    assert Gtin.valid?("5901234123457")   # EAN-13, check 7
    assert Gtin.valid?("0036000291452")   # UPC-A 036000291452 zero-prefixed, check 2
  end

  test "valid? rejects wrong check digits and malformed input" do
    assert_not Gtin.valid?("4006381333930")
    assert_not Gtin.valid?("400638133393")   # 12 digits
    assert_not Gtin.valid?("abcdefghijklm")
  end

  test "check_digit matches published algorithm" do
    assert_equal 1, Gtin.check_digit("400638133393".chars.map(&:to_i))
    assert_equal 2, Gtin.check_digit("003600029145".chars.map(&:to_i))
  end

  # --- normalize ---
  test "normalize passes through a valid 13-digit code" do
    assert_equal "4006381333931", Gtin.normalize("4006381333931")
  end

  test "normalize zero-prefixes a valid 12-digit UPC-A" do
    assert_equal "0036000291452", Gtin.normalize("036000291452")
  end

  test "normalize strips non-digits before interpreting" do
    assert_equal "0036000291452", Gtin.normalize("0-36000-29145-2")
  end

  test "normalize rejects invalid checksums" do
    assert_nil Gtin.normalize("4006381333930")
    assert_nil Gtin.normalize("036000291453")
  end

  test "normalize rejects garbage and wrong lengths" do
    assert_nil Gtin.normalize("")
    assert_nil Gtin.normalize("hello")
    assert_nil Gtin.normalize("123")
    assert_nil Gtin.normalize("12345678")            # 8 digits, no symbology
    assert_nil Gtin.normalize("123456789012345")     # 15 digits
  end

  # --- UPC-E expansion, every last-digit pattern (0..9) ---
  test "normalize expands every UPC-E last-digit pattern" do
    ns = "0"
    # six data digits per case; index 5 (last) drives the expansion table.
    {
      "0" => "1234" + "20", "1" => "5678" + "01", "2" => "2468" + "12",
      "3" => "1357" + "93", "4" => "2461" + "34",
      "5" => "9876" + "15", "6" => "1122" + "36", "7" => "3344" + "57",
      "8" => "5566" + "78", "9" => "7788" + "99"
    }.each_value do |six|
      expected_middle = expand_middle(six)
      body = ns + expected_middle              # 11 digits (NS + 10)
      check = Gtin.check_digit(body.chars.map(&:to_i)).to_s
      upc_e = ns + six + check                 # 8-digit UPC-E the scanner reports
      assert_equal "0#{body}#{check}", Gtin.normalize(upc_e, symbology: :upc_e),
                   "UPC-E #{upc_e} (last digit #{six[5]}) expanded incorrectly"
    end
  end

  # Reference expansion (independent of Gtin#expand_upc_e) for cross-checking.
  def expand_middle(six)
    d = six.chars
    case d[5]
    when "0", "1", "2" then [ d[0], d[1], d[5], "0", "0", "0", "0", d[2], d[3], d[4] ]
    when "3"           then [ d[0], d[1], d[2], "0", "0", "0", "0", "0", d[3], d[4] ]
    when "4"           then [ d[0], d[1], d[2], d[3], "0", "0", "0", "0", "0", d[4] ]
    else                    [ d[0], d[1], d[2], d[3], d[4], "0", "0", "0", "0", d[5] ]
    end.join
  end
end
