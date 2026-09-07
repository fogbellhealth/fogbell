require "test_helper"

module Fogbell
  module Pipeline
    class ExtractorTest < ActiveSupport::TestCase
      setup do
        @tmp = Pathname(Dir.mktmpdir("fogbell-extract"))
        @out = @tmp.join("items")
        @changelog = Changelog.new(@tmp.join("changelog.md"))
        @rejects = @tmp.join("rejects")
      end

      teardown { FileUtils.rm_rf(@tmp) }

      def extractor(llm:, **opts)
        Extractor.new(doc: file_fixture("corpus/fake_manual_x0100.txt"), doc_id: "fake-manual", llm: llm,
                      out_dir: @out, changelog: @changelog, rejects_dir: @rejects, **opts)
      end

      def stub(text: nil)
        Llm::StubClient.new(file_fixture("llm/x0100_response.json"), text: text)
      end

      test "end to end with a stubbed model produces a schema-valid item and a changelog line" do
        llm = stub
        result = extractor(llm: llm).run("X0100")

        assert result.path.exist?
        data = JSON.parse(result.path.read)
        assert_empty Rulebook::Validator.validate(data)
        assert_equal "X0100", data["item_id"]
        assert_equal 7, data["lookback_days"]
        assert_equal 2, data["federal_coding_rules"].size
        data["federal_coding_rules"].each do |rule|
          assert_equal "fake-manual", rule.dig("source", "doc")
          assert_match(/\Ap\. \d+\z/, rule.dig("source", "loc"))
        end
        assert_equal "unreviewed", data.dig("provenance_summary", "expert_review_status")
        assert_equal "stub", data.dig("provenance_summary", "model")
        assert_equal [ { "doc" => "fake-manual" } ], data.dig("provenance_summary", "source_documents")
        assert_equal "0.1.0", data["version"]
        assert_equal Rulebook::Schema.json["properties"].keys & data.keys, data.keys, "keys follow schema order"
        assert_not data["case_mix_relevance"].key?("source"), "nulls from the model are dropped"

        # The loader accepts what the pipeline wrote.
        assert_equal [ "X0100" ], Fogbell::Rulebook.load(@out).ids

        lines = @changelog.path.read.lines
        assert_equal 1, lines.size
        assert_match(/extract · X0100 · doc=fake-manual pages=1-3 model=stub/, lines.first)

        call = llm.calls.first
        assert_match(/\[PAGE 2\]/, call.user)
        assert_match(/NOT_FOUND/, call.system)
        assert_includes call.output_schema["required"], "not_found"
        assert_nil call.pdf
      end

      test "a null lookback_days (NOT_FOUND) survives as an explicit null and validates" do
        payload = JSON.parse(file_fixture("llm/x0100_response.json").read)
        payload["lookback_days"] = nil
        payload["lookback_source"] = nil
        payload["not_found"] = (payload["not_found"] || []) | [ "lookback_days" ]
        result = extractor(llm: stub(text: JSON.generate(payload))).run("X0100")

        data = JSON.parse(result.path.read)
        assert data.key?("lookback_days"), "required nullable key is kept"
        assert_nil data["lookback_days"]
        assert_not data.key?("lookback_source"), "optional nulls are still dropped"
        assert_empty Rulebook::Validator.validate(data)
      end

      test "prepends cited conventions, marked subordinate to the item's pages" do
        conv = [ { "quote" => "The standard look-back period is 7 days, unless otherwise stated.", "rule" => "paraphrase", "source" => { "doc" => "fake-manual", "loc" => "p. 3-3" } } ]
        llm = stub
        extractor(llm: llm, conventions: conv).run("X0100")
        system = llm.calls.first.system
        assert_match(/SUBORDINATE to the item's own pages/, system)
        assert_match(/- "The standard look-back period is 7 days, unless otherwise stated\." \(fake-manual, p\. 3-3\)/, system)
        assert_no_match(/paraphrase/, system, "only the verbatim quote is shown")
      end

      test "conventions_for returns the CONV items' cited rules for an instrument" do
        dir = @tmp.join("conv"); dir.mkpath
        item = JSON.parse(file_fixture("rulebook/valid_item.json").read)
        item["item_id"] = "CONV-TEST"; item["section"] = "CONV"
        dir.join("CONV-TEST.json").write(JSON.generate(item))
        rules = Fogbell::Rulebook.conventions_for("MDS-3.0", "fake-manual", dir)
        assert_equal 2, rules.size, "both fixture rules carry quotes"
        assert_equal({ "doc" => "fake-manual", "loc" => "p. 2" }, rules.first["source"])
        assert_equal "Code 1 only if a visibility check was performed and documented within the look-back period.", rules.first["quote"]
        assert_empty Fogbell::Rulebook.conventions_for("MDS-3.0", "other-doc", dir), "scoped to the document being extracted"
        assert_empty Fogbell::Rulebook.conventions_for("MDS-RCA", "fake-manual", dir)
        assert_empty Fogbell::Rulebook.conventions_for("MDS-3.0", "fake-manual", @tmp.join("nope"))
      end

      test "a hinted id sends the whole text document instead of chunking on the id" do
        llm = stub
        extractor(llm: llm, hint: "the fog conventions").run("X0100")
        assert_match(/\[PAGE 1\]/, llm.calls.first.user)
        assert_match(/\[PAGE 3\]/, llm.calls.first.user)
        assert_match(/What this item covers: the fog conventions/, llm.calls.first.user)
      end

      test "sends only the pages that mention the item" do
        llm = stub
        extractor(llm: llm, window: 0).run("X0100")
        user = llm.calls.first.user
        assert_match(/\[PAGE 1\]/, user)
        assert_match(/\[PAGE 3\]/, user)
        assert_match(/extract · X0100 · doc=fake-manual pages=1-3/, @changelog.path.read)
      end

      test "schema-invalid model output is rejected, saved for inspection, and never written" do
        bad = JSON.parse(file_fixture("llm/x0100_response.json").read)
        bad["federal_coding_rules"][1].delete("source")
        error = assert_raises(Rejected) { extractor(llm: stub(text: JSON.generate(bad))).run("X0100") }

        assert_match(%r{/federal_coding_rules/1}, error.message)
        assert error.reject_path.exist?
        assert_not @out.join("X0100.json").exist?
        assert_not @changelog.path.exist?
      end

      test "an item id that does not match the request is rejected" do
        wrong = JSON.parse(file_fixture("llm/x0100_response.json").read).merge("item_id" => "X0200")
        error = assert_raises(Rejected) { extractor(llm: stub(text: JSON.generate(wrong))).run("X0100") }
        assert_match(/expected "X0100"/, error.message)
      end

      test "non-JSON output is rejected" do
        error = assert_raises(Rejected) { extractor(llm: stub(text: "Sorry, I cannot")).run("X0100") }
        assert_match(/not valid JSON/, error.message)
      end

      test "refuses to overwrite without force" do
        extractor(llm: stub).run("X0100")
        assert_raises(AlreadyExists) { extractor(llm: stub).run("X0100") }
        assert_nothing_raised { extractor(llm: stub, force: true).run("X0100") }
      end

      test "an unknown item raises NoMatch before any model call" do
        llm = stub
        assert_raises(NoMatch) { extractor(llm: llm).run("Z9999") }
        assert_empty llm.calls
      end

      test "prompt_for renders without calling the model" do
        llm = stub
        prompt = extractor(llm: llm).prompt_for("X0100")
        assert_match(/Item to extract: \*\*X0100\*\*/, prompt.user)
        assert_match(/"lookback_source"/, prompt.system)
        assert_empty llm.calls
      end

      test "MODE=pdf attaches the document instead of page text" do
        Dir.mktmpdir do |dir|
          pdf = File.join(dir, "scan.pdf")
          File.binwrite(pdf, "%PDF-1.4 pretend")
          shell = Struct.new(:x) { def available?(_) = true; def run(*) = "" }.new
          llm = stub
          Extractor.new(doc: pdf, doc_id: "scan", llm: llm, out_dir: @out, changelog: @changelog,
                        rejects_dir: @rejects, mode: "auto", shell: shell).run("X0100")
          call = llm.calls.first
          assert_equal "%PDF-1.4 pretend", call.pdf
          assert_match(/The source document is attached/, call.user)
          assert_match(/pages=all/, @changelog.path.read)
        end
      end
    end
  end
end
