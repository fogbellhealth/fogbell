# frozen_string_literal: true

module Fogbell
  # The rule-changes feed: detected changes in the corpus's own source documents. Two kinds —
  # curated revision diffs (a source document itself changed between two dated versions) and
  # corpus additions (a new document was manifested and extracted) — merged and sorted by date.
  # Corpus-agnostic: additions are read live from corpus/MANIFEST.md; only the OMIG diff is
  # hand-curated, because a two-revision text diff isn't something the manifest records.
  module CorpusChanges
    Entry = Data.define(:date, :kind, :document, :summary, :diff, :item_ids)

    MANIFEST_ROW = /\A\|\s*`(?<key>[^`]+)`\s*\|\s*(?<title>[^|]*)\|\s*(?<version>[^|]*)\|\s*(?<source>[^|]*)\|\s*(?<downloaded>[^|]*)\|\s*(?<sha256>[^|]*)\|\s*(?<status>[^|]*)\|/

    # Verbatim before/after text for the one revision diff worth showing in detail. The full
    # protocol diff was mostly retypesetting noise; this is the one substantive change, quoted
    # from both PDFs at the cited page.
    OMIG_SIGNATURE_DIFF = Entry.new(
      date: Date.new(2025, 12, 26),
      kind: "revision",
      document: "omig-alp-protocol-2025-12",
      summary: "OMIG loosened who may sign a medical evaluation or reassessment (Areas 6 and 8): a form-specific PA/NP carve-out was replaced with a flat date-based rule allowing a physician, PA, or NP for services on or after 02/19/14.",
      diff: [
        {
          area: "Area 6 — Medical Evaluation Does Not Meet Requirements",
          before: { label: "Rev. 11/20/2025", loc: "p. 6", quote: "A medical evaluation must be dated and signed by a physician. Medical evaluations require the date of the resident's physical examination and must be completed within 30 days from the examination date. For newly admitted residents, the physical examination must occur within 30 days of the admission date. If the medical evaluation does not meet the requirements, the claim will be disallowed.\n\n*Form DOH 4449-C may be completed and signed by a physician assistant or nurse practitioner in lieu of a physician." },
          after: { label: "Rev. 12/26/2025", loc: "p. 6", quote: "Medical evaluations require the date of the resident's physical examination and must be completed within 30 days from the examination date. For newly admitted residents, the physical examination must occur within 30 days of the admission date. If the medical evaluation does not meet the requirements, the claim will be disallowed.\nFor Services 02/19/14 and After:\nA medical evaluation must be dated and signed by a physician, physician's assistant, or a nurse practitioner.\nFor Services 09/28/89 to 02/18/14:\nA medical evaluation must be dated and signed by a physician." }
        },
        {
          area: "Area 8 — Medical Reassessment Does Not Meet Requirements",
          before: { label: "Rev. 11/20/2025", loc: "p. 8", quote: "A medical reassessment must be dated and signed by a physician. Reassessments must be conducted as frequently as required to respond to changes in a resident's condition, but in no event less frequently than once every six months. If the reassessment is not completed in the time frame required or does not include an authorized practitioner's signature and date, the claim will be disallowed.\n\n*Form DSS-4568 may be completed and signed by a physician assistant or nurse practitioner in lieu of a physician." },
          after: { label: "Rev. 12/26/2025", loc: "p. 8", quote: "Reassessments must be conducted as frequently as required to respond to changes in a resident's condition, but in no event less frequently than once every six months. If the reassessment is not completed in the time frame required or does not include an authorized practitioner's signature and date, the claim will be disallowed.\nFor Services 02/19/14 and After:\nA medical reassessment must be dated and signed by a physician, physician's assistant, or a nurse practitioner.\nFor Services 09/28/89 to 02/18/14:\nA medical reassessment must be dated and signed by a physician." }
        }
      ],
      item_ids: %w[CONV-NY-OMIG-ALP-06 CONV-NY-OMIG-ALP-08]
    )

    class << self
      # All entries, newest first.
      def all(manifest_path: Rails.root.join("corpus/MANIFEST.md"))
        (manifest_additions(manifest_path) + [ OMIG_SIGNATURE_DIFF ]).sort_by(&:date).reverse
      end

      private

      # One entry per manifest row that has a downloaded date and at least one promoted item
      # citing it — a corpus addition worth telling a reviewer about, not a still-empty TODO row.
      def manifest_additions(path)
        return [] unless path.exist?

        rows = path.each_line.filter_map { |l| MANIFEST_ROW.match(l) }
        rows.filter_map do |m|
          downloaded = m[:downloaded].to_s.strip
          next if downloaded.blank?

          date = Date.parse(downloaded) rescue nil
          next unless date

          key = m[:key]
          items = Rulebook.instance.select { |i| i.provenance_summary.dig("source_documents", 0, "doc") == key }.map(&:item_id)
          next if items.empty?

          Entry.new(date: date, kind: "addition", document: key,
                    summary: "#{m[:title].to_s.strip} added to the corpus — #{pluralize_items(items.size)} extracted and promoted.",
                    diff: nil, item_ids: items.sort)
        end
      end

      def pluralize_items(n) = "#{n} item#{'s' unless n == 1}"
    end
  end
end
