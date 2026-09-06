# frozen_string_literal: true

require "open3"

module Fogbell
  module Pipeline
    # Tiny seam around external commands (pdftotext etc.) so the PDF path is testable.
    class Shell
      def available?(command)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
          File.executable?(File.join(dir, command))
        end
      end

      # Runs +argv+ and returns stdout. Raises Pipeline::Error with stderr on a non-zero exit.
      def run(*argv)
        stdout, stderr, status = Open3.capture3(*argv)
        raise Error, "#{argv.first} failed (exit #{status.exitstatus}): #{stderr.strip}" unless status.success?

        stdout
      end
    end
  end
end
