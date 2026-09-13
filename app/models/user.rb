# Two orthogonal role domains, not a privilege hierarchy — see CLAUDE.md's "Role model" note.
# Facility-domain roles (nurse, don) belong to a Facility and are scoped to its residents,
# assessments, charts and checks. Rulebook-domain roles (verifier, staff) have no facility
# affiliation and can never reach facility data, by policy AND by scope (see the *_area policies
# and how controllers build their scopes from current_user.facility).
class User < ApplicationRecord
  devise :database_authenticatable, :rememberable, :validatable

  FACILITY_ROLES = %w[nurse don].freeze
  RULEBOOK_ROLES = %w[verifier staff].freeze
  ROLES = (FACILITY_ROLES + RULEBOOK_ROLES).freeze

  belongs_to :facility, optional: true

  validates :role, inclusion: { in: ROLES }
  validate :facility_matches_role_domain

  # Development convenience only — never a real role. Grants both domains on top of whatever the
  # base role already grants, so the account can demo both surfaces. Seeded, clearly labeled,
  # never the shape of a real user: a real verifier still cannot see facility data, ever.
  def dev_both_domains? = dev_both_domains

  def facility_domain? = FACILITY_ROLES.include?(role) || dev_both_domains?
  def rulebook_domain? = RULEBOOK_ROLES.include?(role) || dev_both_domains?

  private

  def facility_matches_role_domain
    if FACILITY_ROLES.include?(role) && facility_id.blank?
      errors.add(:facility_id, "must be present for role #{role.inspect} (facility domain)")
    elsif RULEBOOK_ROLES.include?(role) && facility_id.present?
      errors.add(:facility_id, "must be blank for role #{role.inspect} — rulebook-domain users have no facility affiliation")
    end
  end
end
