require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup { @facility = Facility.create!(name: "Test Facility (fictional, synthetic)") }

  test "a facility role requires a facility" do
    user = User.new(email: "a@example.test", password: "password123", role: "nurse", facility: nil)
    assert_not user.valid?
    assert_includes user.errors[:facility_id].join, "must be present"
  end

  test "a rulebook role forbids a facility" do
    user = User.new(email: "b@example.test", password: "password123", role: "verifier", facility: @facility)
    assert_not user.valid?
    assert_includes user.errors[:facility_id].join, "must be blank"
  end

  test "facility_domain? and rulebook_domain? are mutually exclusive for real roles" do
    nurse = create_user(role: "nurse", facility: @facility)
    don = create_user(role: "don", facility: @facility)
    verifier = create_user(role: "verifier")
    staff = create_user(role: "staff")

    assert nurse.facility_domain? && !nurse.rulebook_domain?
    assert don.facility_domain? && !don.rulebook_domain?
    assert verifier.rulebook_domain? && !verifier.facility_domain?
    assert staff.rulebook_domain? && !staff.facility_domain?
  end

  test "dev_both_domains grants both domains on top of a facility role, and is not itself a role" do
    both = create_user(role: "nurse", facility: @facility, dev_both_domains: true)
    assert both.facility_domain?
    assert both.rulebook_domain?
    assert_equal "nurse", both.role
  end
end
