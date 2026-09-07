require "test_helper"

module Fogbell
  module EvidenceCheck
    class RunnerTest < ActiveSupport::TestCase
      class FakeRegistry
        def initialize(items) = @items = items
        include Enumerable
        def each(&) = @items.each(&)
        def fetch(id) = @items.find { |i| i.item_id == id } or raise KeyError, id
        def find(id) = @items.find { |i| i.item_id == id }
        def ids = @items.map(&:item_id)
      end

      setup do
        @item = Rulebook::Item.from_hash(JSON.parse(file_fixture("rulebook/valid_item.json").read))
        @registry = FakeRegistry.new([ @item ])
        @check = Check.new(chart_text: "09/02/2026 note", ard: Date.new(2026, 9, 3), item_ids: [ "X0100" ], status: "queued")
        @check.save!(validate: false)
        @log_dir = Pathname(Dir.mktmpdir("fogbell-ec"))
      end

      teardown { FileUtils.rm_rf(@log_dir) }

      def runner(llm)
        Runner.new(@check, llm: llm, rulebook: @registry, log_dir: @log_dir)
      end

      def stub(text)
        Pipeline::Llm::StubClient.new(text: text)
      end

      test "a valid response yields per-item results with the window enforced in code" do
        yielded = []
        result = runner(stub(file_fixture("evidence_check/valid_response.json").read)).run { |r| yielded << r }
        assert_equal 1, result.attempts
        r = result.items.first
        assert_equal [ r ], yielded
        assert_equal "supported", r["status"]
        assert_equal 1, r["evidence"].size, "the 08/20 note is 14 days before the ARD and cannot count"
        assert_equal 1, r["outside_window_evidence"].size
        assert_equal "2026-08-28", r["window"]["first_day"]
        assert_equal 1, @log_dir.glob("check-*.json").size, "request/response logged"
        logged = JSON.parse(@log_dir.glob("check-*.json").first.read)
        assert_match(/Evidence outside the look-back window is listed but never counted/, logged["system"])
        assert_match(/never suggest documenting care that did not occur/i, logged["system"])
      end

      test "a status with only out-of-window evidence is downgraded to unsupported" do
        payload = JSON.parse(file_fixture("evidence_check/valid_response.json").read)
        payload["items"][0]["evidence"] = [ payload["items"][0]["evidence"][1] ]
        r = runner(stub(JSON.generate(payload))).run.items.first
        assert_equal "unsupported", r["status"]
        assert r["downgraded"]
        assert_match(/outside the 7-day window/, r["gaps"].last)
      end

      test "an invalid response is retried once, then fails with a user-visible error" do
        llm = stub('{"items": "nope"}')
        error = assert_raises(InvalidResponse) { runner(llm).run }
        assert_equal 2, llm.calls.size
        assert_match(/unusable answer 2 times/, error.message)
        assert_equal 2, @log_dir.glob("check-*.json").size
      end

      test "the prompt numbers the item's rules and includes the chart and ARD" do
        p = runner(stub("{}")).prompt
        assert_match(/\[R1\] Code 1 only if a visibility check/, p.user)
        assert_match(/September 3, 2026/, p.user)
        assert_match(/7 days: Aug 28, 2026 through Sep 3, 2026/, p.user)
        assert_match(/09\/02\/2026 note/, p.user)
        assert_match(/Conservative coding only/, p.system)
      end
    end
  end
end
