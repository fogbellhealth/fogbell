require "test_helper"

module Fogbell
  module Review
    class PageTest < ActiveSupport::TestCase
      setup do
        @item = Rulebook::Item.from_hash(JSON.parse(file_fixture("rulebook/valid_item.json").read))
        @manifest = Manifest.new(Rails.root.join("corpus/MANIFEST.md"))
        @page = Page.new(@item, manifest: @manifest).render
      end

      test "renders the header with name, instrument and status" do
        assert_match(/^# X0100 — Fog Visibility Check/, @page)
        assert_match(/MDS 3\.0 · Section X/, @page)
        assert_match(/status: unreviewed/, @page)
      end

      test "footnotes every citation and lists it under Sources with the quote" do
        n_citations = @item.citations.uniq.size
        sources = @page[/## Sources\n(.*)\z/m, 1]
        assert_equal n_citations, sources.scan(/^\[\^\d+\]:/).size
        assert_match(/\[\^\d+\]: fake-manual, p\. 2 — “Look back over the 7-day period ending on the ARD\.”/, sources)
        assert_match(/\*\*7 days\*\*\[\^1\]/, @page)
      end

      test "gives every coding rule and documentation requirement a checkbox line" do
        review = @page[/## Your review\n(.*?)## Sources/m, 1]
        assert_equal @item.federal_coding_rules.size, review.scan(/^- Rule \d+: ☐ correct/).size
        assert_equal 1, review.scan(/^- Requirement \d+: ☐ correct/).size
      end

      test "renders conflicts as a distinct quoted block with both positions" do
        assert_match(/## ⚠️ Conflicts/, @page)
        assert_match(/^> - \*fake-manual:\* The ARD is included/, @page)
        assert_match(/^> - \*fake-manual:\* Checks on the day of assessment are excluded/, @page)
        assert_match(/^> Status: unresolved — surface to user/, @page)
      end

      test "translates not-found keys into plain English and never prints JSON vocabulary" do
        assert_match(/- whether this item affects the case-mix classification/, @page)
        assert_no_match(/lookback_days|federal_coding_rules|supportive_documentation|not_found/, @page)
      end

      test "manifest shows a readable document name" do
        assert_equal "RAI Manual v1.20.1 (Oct 2025)", @manifest.name("rai-manual-v1.20.1")
        assert_equal "unknown-key", @manifest.name("unknown-key")
      end
    end
  end
end
