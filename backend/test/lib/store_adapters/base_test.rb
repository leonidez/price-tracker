require "test_helper"

class StoreAdapters::BaseTest < ActiveSupport::TestCase
  def adapter
    StoreAdapters::Generic.new(stores(:generic))
  end

  test "verified_gtin? matches across UPC-A (12) and EAN-13 (13) formats" do
    subject = adapter
    assert subject.send(:verified_gtin?, [ "036000291452" ], "0036000291452")
    assert subject.send(:verified_gtin?, [ "0036000291452" ], "036000291452")
    assert subject.send(:verified_gtin?, [ "0036000291452", "0000000000000" ], "0036000291452")
  end

  test "verified_gtin? is false for a non-match, empty list, or bad scan" do
    subject = adapter
    assert_not subject.send(:verified_gtin?, [ "4006381333931" ], "0036000291452")
    assert_not subject.send(:verified_gtin?, [], "0036000291452")
    assert_not subject.send(:verified_gtin?, [ "036000291452" ], "not-a-code")
  end
end
