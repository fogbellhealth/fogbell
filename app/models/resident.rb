# Synthetic label only ("Resident 04") — never a name, never a DOB. See CLAUDE.md's Data model
# note: this is demo fixture data standing in for a future EHR feed, not the product's real schema.
class Resident < ApplicationRecord
  belongs_to :facility
  has_many :assessments, dependent: :destroy

  validates :label, presence: true
end
