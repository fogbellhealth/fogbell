require "test_helper"

module Fogbell
  module Pipeline
    class StateLayererTest < ActiveSupport::TestCase
      setup do
        @tmp = Pathname(Dir.mktmpdir("fogbell-layer"))
        @items = @tmp.join("items"); @items.mkpath
        @items.join("X0100.json").write(file_fixture("rulebook/valid_item.json").read)
        @out = @tmp.join("layered")
        @changelog = Changelog.new(@tmp.join("changelog.md"))
      end

      teardown { FileUtils.rm_rf(@tmp) }

      def layerer(llm:, **opts)
        StateLayerer.new(doc: file_fixture("corpus/me_fake_rule.txt"), doc_id: "me-fake-rule", state: "ME", llm: llm,
                         items_dir: @items, out_dir: @out, changelog: @changelog, rejects_dir: @tmp.join("rejects"), **opts)
      end

      def stub(text: nil)
        Llm::StubClient.new(file_fixture("llm/x0100_layer_me_response.json"), text: text)
      end

      test "merges state criteria, deltas, conflicts and case-mix into a valid item and logs it" do
        llm = stub
        result = layerer(llm: llm).run("X0100")
        data = JSON.parse(result.path.read)

        assert_empty Rulebook::Validator.validate(data)
        assert_equal 1, data.dig("supportive_documentation", "state", "ME").size
        assert_equal "me-fake-rule", data.dig("supportive_documentation", "state", "ME", 0, "source", "doc")
        assert_equal [ "ME" ], data["state_deltas"].map { |d| d["state"] }
        assert_equal 2, data["conflicts"].size, "the federal conflict is kept and the fed/state one added"
        assert_equal "high", data.dig("case_mix_relevance", "level"), "unknown federal relevance is replaced by the cited state finding"
        assert_includes data.dig("provenance_summary", "source_documents").map { |d| d["doc"] }, "me-fake-rule"
        assert_equal 2, data["federal_coding_rules"].size, "federal rules untouched"
        assert_match(/layer_state · X0100 · doc=me-fake-rule pages=all model=stub · state=ME criteria=1 deltas=1 conflicts=1 case_mix=1; not found: sanctions for missing checks/, @changelog.path.read)

        call = llm.calls.first
        assert_match(/\[PAGE 2\]/, call.document_text, "the whole state document is sent as a cached text block")
        assert_match(/Look back over the 7-day period/, call.user, "the federal baseline is in the prompt")
        assert_match(/State: \*\*ME\*\*/, call.user)
        assert_nil call.pdf
      end

      test "re-running replaces this layer's findings instead of duplicating them" do
        layerer(llm: stub).run("X0100")
        @items.join("X0100.json").write(@out.join("X0100.json").read) # promote the layered item
        layerer(llm: stub, force: true).run("X0100")
        data = JSON.parse(@out.join("X0100.json").read)
        assert_equal 1, data["state_deltas"].size
        assert_equal 2, data["conflicts"].size
      end

      test "rejects a finding that cites anything other than the state document" do
        payload = JSON.parse(file_fixture("llm/x0100_layer_me_response.json").read)
        payload["state_deltas"][0]["source"]["doc"] = "fake-manual"
        error = assert_raises(Rejected) { layerer(llm: stub(text: JSON.generate(payload))).run("X0100") }
        assert_match(/state delta 1 cites "fake-manual"/, error.message)
        assert_not @out.join("X0100.json").exist?
      end

      test "requires a promoted item and a two-letter state" do
        assert_raises(Error) { layerer(llm: stub).run("NOPE") }
        assert_raises(Error) { StateLayerer.new(doc: file_fixture("corpus/me_fake_rule.txt"), doc_id: "x", state: "Maine", llm: stub, items_dir: @items, out_dir: @out) }
      end
    end
  end
end
