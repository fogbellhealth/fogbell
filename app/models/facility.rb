# A fictional facility standing in for future EHR-fed data. See CLAUDE.md's Data model note:
# this fixture (Facility/Resident/Assessment) is a demo stand-in, not the product's real schema.
class Facility < ApplicationRecord
  has_many :residents, dependent: :destroy
end
