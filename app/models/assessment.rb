# One resident's upcoming (or closed) assessment window, with a pre-run Check against a single
# "item at risk" cached via check_id. See CLAUDE.md's Data model note: demo fixture data standing
# in for a future EHR feed, not the product's real schema. No resident identity is stored on the
# Check itself (see Check's own comment) — only here, on the fixture side.
class Assessment < ApplicationRecord
  TYPES = %w[admission quarterly annual significant_change].freeze
  STATUSES = %w[open closed].freeze

  belongs_to :resident
  belongs_to :check, optional: true

  validates :assessment_type, inclusion: { in: TYPES }
  validates :ard, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :open_windows, -> { where(status: "open").order(:ard) }

  def open? = status == "open"
  def closed? = status == "closed"
  def days_remaining = (ard - Date.current).to_i

  def focus_item
    Fogbell::Rulebook.instance.find(focus_item_id)
  end

  # The single per-item result the pre-run check produced for focus_item_id, or nil if the check
  # hasn't finished (or failed).
  def finding
    return nil unless check&.done?

    check.results.find { |r| r["item_id"] == focus_item_id || r["item_id"].start_with?(focus_item_id) }
  end
end
