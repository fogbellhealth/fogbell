# frozen_string_literal: true

module Fogbell
  module Pipeline
    module Llm
      # What every LLM client returns from #complete.
      Response = Data.define(:text, :model, :usage)
    end
  end
end
