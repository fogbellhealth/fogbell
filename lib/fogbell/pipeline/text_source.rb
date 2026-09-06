# frozen_string_literal: true

module Fogbell
  module Pipeline
    # Turns a corpus file into numbered pages.
    #
    # * .txt  — pages separated by form-feed (\f); a file without \f is one page.
    # * .pdf  — `pdftotext -layout` (poppler), which emits \f between pages.
    #
    # Form/scanned PDFs yield almost no text; #looks_scanned? detects that so the
    # extractor can fall back to sending the PDF itself to the API as a document block.
    class TextSource
      SCANNED_CHARS_PER_PAGE = 200
      INSTALL_HINT = "pdftotext not found. Install poppler (macOS: `brew install poppler`, Debian: `apt install poppler-utils`) " \
                     "or run with MODE=pdf to send the document to the API directly."

      attr_reader :path

      def initialize(path, shell: Shell.new)
        @path = Pathname(path)
        @shell = shell
        raise Error, "document not found: #{@path}" unless @path.file?
      end

      def kind
        @path.extname.casecmp?(".pdf") ? :pdf : :text
      end

      def pages
        @pages ||= split_pages(kind == :pdf ? pdftotext : @path.read)
      end

      def looks_scanned?
        return false if kind == :text
        return true if pages.empty?

        (pages.sum(&:chars).to_f / pages.size) < SCANNED_CHARS_PER_PAGE
      end

      def pdf_bytes
        raise Error, "#{@path} is not a PDF" unless kind == :pdf

        @path.binread
      end

      private

      def pdftotext
        raise MissingTool, INSTALL_HINT unless @shell.available?("pdftotext")

        @shell.run("pdftotext", "-layout", @path.to_s, "-")
      end

      def split_pages(text)
        chunks = text.split("\f")
        chunks.pop while chunks.any? && chunks.last.strip.empty?
        chunks.each_with_index.map { |chunk, index| Page.new(number: index + 1, text: chunk) }
      end
    end
  end
end
