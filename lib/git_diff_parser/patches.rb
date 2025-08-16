require 'delegate'
module GitDiffParser
  # The array of patch
  class Patches < DelegateClass(Array)
    # @return [Patches<Patch>]
    def self.[](*ary)
      new(ary)
    end

    # @param contents [String] `git diff` result
    #
    # @return [Patches<Patch>] parsed object
    def self.parse(contents)
      body          = false
      file_name     = ''
      orig_file_name = ''
      patch         = []
      diff_type     = :change

      lines    = contents.lines
      line_count = lines.count
      parsed   = new

      lines.each_with_index do |line, count|
        case line.chomp
        when /^diff/
          unless patch.empty?
            parsed << Patch.new(
              patch.join("\n") + "\n",
              file: file_name,
              orig_file: orig_file_name,
              diff_type: diff_type
            )
            patch.clear
            file_name      = ''
            orig_file_name = ''
            diff_type      = :change
          end
          body = false

        when %r{^\-\-\- a/(?<file_name>.*)}
          orig_file_name = Regexp.last_match[:file_name]

        when %r{^\-\-\- /dev/null}
          orig_file_name = nil

        when %r{^\+\+\+ b/(?<file_name>.*)}
          file_name  = Regexp.last_match[:file_name]
          body       = true
          diff_type  = orig_file_name.nil? ? :add : :change

        when %r{^\+\+\+ /dev/null}
          file_name  = orig_file_name
          body       = true
          diff_type  = :delete

        when /^(?<body>[\ @\+\-\\].*)/
          patch << Regexp.last_match[:body] if body
          if !patch.empty? && body && line_count == count + 1
            parsed << Patch.new(
              patch.join("\n") + "\n",
              file: file_name,
              orig_file: orig_file_name,
              diff_type: diff_type
            )
            patch.clear
            file_name      = ''
            orig_file_name = ''
            diff_type      = :change
          end
        end
      end

      parsed
    end


    # @return [String]
    def scrub_string(line)
      if RUBY_VERSION >= '2.1'
        line.scrub
      else
        line.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      end
    end

    # @return [Patches<Patch>]
    def initialize(*args)
      super Array.new(*args)
    end

    # @return [Array<String>] file path
    def files
      map(&:file)
    end

    # @return [Array<String>] target sha1 hash
    def secure_hashes
      map(&:secure_hash)
    end

    # @param file [String] file path
    #
    # @return [Patch, nil]
    def find_patch_by_file(file)
      find { |patch| patch.file == file }
    end

    # @param secure_hash [String] target sha1 hash
    #
    # @return [Patch, nil]
    def find_patch_by_secure_hash(secure_hash)
      find { |patch| patch.secure_hash == secure_hash }
    end
  end
end
