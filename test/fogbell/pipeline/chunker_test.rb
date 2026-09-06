require "test_helper"

module Fogbell
  module Pipeline
    class ChunkerTest < ActiveSupport::TestCase
      def pages(*texts)
        texts.each_with_index.map { |t, i| Page.new(number: i + 1, text: t) }
      end

      test "selects matching pages plus a window on each side" do
        docs = pages("intro", "about G0110 here", "more G0110", "unrelated", "unrelated", "unrelated", "G0120 only")
        selection = Chunker.new(docs, window: 1).select("G0110A")
        assert_equal [ 2, 3 ], selection.matched
        assert_equal [ 1, 2, 3, 4 ], selection.numbers
      end

      test "sub-items share their parent's pages" do
        assert_equal(/\bG0110/, Chunker.pattern_for("G0110A"))
        assert_equal(/\bX0100/, Chunker.pattern_for("X0100"))
        assert_match Chunker.pattern_for("G0110A"), "See G0110 for ADL coding"
        assert_no_match Chunker.pattern_for("G0110A"), "See AG0110 for nothing"
      end

      test "raises when nothing matches" do
        assert_raises(NoMatch) { Chunker.new(pages("nothing", "here")).select("Z9999") }
      end

      test "keeps matched pages first when the char budget is tight" do
        docs = pages("a" * 100, "G0110 " + ("b" * 94), "c" * 100, "d" * 100)
        selection = Chunker.new(docs, window: 2, max_chars: 250).select("G0110")
        assert_includes selection.numbers, 2
        assert_equal 2, selection.pages.size
        assert_equal selection.numbers, selection.numbers.sort
      end

      test "renders pages with [PAGE n] markers" do
        rendered = Chunker.render(pages("one\n", "two"))
        assert_equal "[PAGE 1]\none\n\n[PAGE 2]\ntwo", rendered
      end
    end
  end
end
