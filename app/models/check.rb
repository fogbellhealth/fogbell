# One evidence check: pasted (synthetic) chart text, an ARD, selected rulebook items, and the
# validated per-item results once the job has run. No resident identity is ever stored.
class Check < ApplicationRecord
  STATUSES = %w[queued running done failed].freeze

  belongs_to :facility, optional: true

  validates :chart_text, presence: true, length: { maximum: 60_000 }
  validates :ard, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :items_exist

  after_initialize { self.status ||= "queued"; self.item_ids ||= []; self.results ||= [] }

  def items = item_ids.map { |id| Fogbell::Rulebook.instance.fetch(id) }
  def done? = status == "done"
  def failed? = status == "failed"
  def finished? = done? || failed?

  private

  def items_exist
    errors.add(:item_ids, "must include at least one item") if item_ids.blank?
    unknown = item_ids.reject { |id| Fogbell::Rulebook.instance.find(id) }
    errors.add(:item_ids, "unknown: #{unknown.join(', ')}") if unknown.any?
    conv = item_ids.select { |id| Fogbell::Rulebook.instance.find(id)&.section == "CONV" }
    errors.add(:item_ids, "convention items are context, not checkable: #{conv.join(', ')}") if conv.any?
  end
end
