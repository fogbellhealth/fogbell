# One reviewer's markup on one rule or documentation criterion within a rulebook item. Written by
# the web app (status "pending"); never applied to rulebook/items/*.json directly from an HTTP
# request. `rake rulebook:apply_review` materializes pending reviews into the item JSON and marks
# them "applied" — see that task for the only path that writes to the corpus.
class RuleReview < ApplicationRecord
  VERDICTS = %w[correct incorrect applied_differently].freeze
  STATUSES = %w[pending applied rejected].freeze
  # target is "rule:<index>" or "criterion:<index>" — which array entry on the item this markup is about.
  TARGET_RE = /\A(rule|criterion):\d+\z/

  belongs_to :reviewer, class_name: "User"

  validates :item_id, presence: true
  validates :target, format: { with: TARGET_RE }
  validates :verdict, inclusion: { in: VERDICTS }
  validates :status, inclusion: { in: STATUSES }
  validates :submitted_at, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :for_item, ->(item_id) { where(item_id: item_id) }

  after_initialize { self.status ||= "pending"; self.submitted_at ||= Time.current }

  def target_kind = target.split(":").first
  def target_index = target.split(":").last.to_i
  def rule_target? = target_kind == "rule"
  def criterion_target? = target_kind == "criterion"
end
