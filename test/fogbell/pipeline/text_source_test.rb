require "test_helper"

module Fogbell
  module Pipeline
    class TextSourceTest < ActiveSupport::TestCase
      FakeShell = Struct.new(:available, :output) do
        def available?(_command) = available
        def run(*argv)
          @argv = argv
          output
        end
        attr_reader :argv
      end

      test "a .txt file splits into pages on form-feed" do
        source = TextSource.new(file_fixture("corpus/fake_manual_x0100.txt"))
        assert_equal :text, source.kind
        assert_equal [ 1, 2, 3 ], source.pages.map(&:number)
        assert_match(/X0100: Fog Visibility Check/, source.pages.first.text)
        assert_not source.looks_scanned?
      end

      test "a .pdf file goes through pdftotext -layout and splits on form-feed" do
        Dir.mktmpdir do |dir|
          pdf = File.join(dir, "manual.pdf")
          File.binwrite(pdf, "%PDF-1.4 fake")
          shell = FakeShell.new(true, "page one text here\fpage two text here\f")
          source = TextSource.new(pdf, shell: shell)

          assert_equal :pdf, source.kind
          assert_equal [ "page one text here", "page two text here" ], source.pages.map(&:text)
          assert_equal [ "pdftotext", "-layout", pdf, "-" ], shell.argv
          assert source.looks_scanned?, "short pages should be flagged as scanned"
          assert_equal "%PDF-1.4 fake", source.pdf_bytes
        end
      end

      test "a missing pdftotext raises with an install hint" do
        Dir.mktmpdir do |dir|
          pdf = File.join(dir, "manual.pdf")
          File.binwrite(pdf, "%PDF")
          error = assert_raises(MissingTool) { TextSource.new(pdf, shell: FakeShell.new(false, "")).pages }
          assert_match(/brew install poppler/, error.message)
        end
      end

      test "a missing document raises" do
        assert_raises(Error) { TextSource.new("nope/missing.txt") }
      end
    end
  end
end
