# A fictional facility standing in for future EHR-fed data. See CLAUDE.md's Data model note:
# this fixture (Facility/Resident/Assessment) is a demo stand-in, not the product's real schema.
class Facility < ApplicationRecord
  has_many :residents, dependent: :destroy
  has_many :assessments, through: :residents
  has_many :users, dependent: :nullify
  has_many :checks, dependent: :nullify
end
