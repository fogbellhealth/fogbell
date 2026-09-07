# Runs one evidence check in the background and streams cards to the page as items finalize.
class RunCheckJob < ApplicationJob
  queue_as :default

  def perform(check)
    check.update!(status: "running")
    results = []
    result = Fogbell::EvidenceCheck::Runner.new(check).run do |item_result|
      results << item_result
      check.update!(results: results)
      Turbo::StreamsChannel.broadcast_append_to(check, target: "cards", partial: "checks/card",
                                                locals: { result: item_result, check: check, rule_set: nil })
    end
    check.update!(status: "done", results: result.items, usage: result.usage.to_h, error: nil)
    Turbo::StreamsChannel.broadcast_replace_to(check, target: "banner", partial: "checks/banner", locals: { check: check })
    Turbo::StreamsChannel.broadcast_replace_to(check, target: "status", partial: "checks/status", locals: { check: check })
  rescue Fogbell::EvidenceCheck::Error, Fogbell::Pipeline::Error => e
    check.update!(status: "failed", error: e.message)
    Turbo::StreamsChannel.broadcast_replace_to(check, target: "status", partial: "checks/status", locals: { check: check })
  end
end
