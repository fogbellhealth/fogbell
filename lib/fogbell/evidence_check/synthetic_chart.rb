# frozen_string_literal: true

module Fogbell
  module EvidenceCheck
    # The demo record. Entirely invented: a fictional facility, a resident identified only as
    # "Resident T.", and dates arranged around DEFAULT_ARD so that the default mood/behavior
    # check yields a mix of supported, partial, unsupported and outside-window results.
    module SyntheticChart
      DEFAULT_ARD = Date.new(2026, 9, 3)

      def self.text
        Rails.root.join("lib/fogbell/evidence_check/synthetic_chart.txt").read
      end
    end
  end
end
