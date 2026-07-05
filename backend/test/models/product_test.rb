require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "valid product" do
    assert products(:cola).valid?
  end

  test "requires gtin13" do
    product = Product.new(gtin13: nil)
    assert_not product.valid?
    assert product.errors[:gtin13].present?
  end

  test "gtin13 must be 13 digits" do
    assert_not Product.new(gtin13: "123").valid?
    assert_not Product.new(gtin13: "12345678901234").valid?
    assert_not Product.new(gtin13: "abcdefghijklm").valid?
    assert Product.new(gtin13: "0005555500005").valid?
  end

  test "gtin13 is unique" do
    dup = Product.new(gtin13: products(:cola).gtin13)
    assert_not dup.valid?
    assert dup.errors[:gtin13].present?
  end

  test "destroying a product destroys its listings" do
    product = products(:cola)
    assert_difference("Listing.count", -product.listings.count) do
      product.destroy
    end
  end
end
