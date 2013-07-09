module BlogHelpers
  def render_code(filename, language, options = {})
    code = File.readlines(guess_full_path(filename))
    if options[:range]
      if !options[:range].is_a?(Array) ||
        options[:range].length != 2 ||
        ! options[:range].first.is_a?(Integer) ||
        ! options[:range].last.is_a?(Integer)
        raise "range must be an array of two integers"
      end
      first = options[:range].first
      last = options[:range].last
      code = code[(first - 1)..(last - 1)]
    end
    options = {
      :linenos => "table",
      :linenostart => first || 1,
      :encoding => 'utf-8'
    }

    formatted_code = Pygments.highlight(code.join, :lexer => language, :options => options)

    # Workaround for https://github.com/tmm1/pygments.rb/pull/51
    formatted_code += '>' unless formatted_code =~ />\z/

    <<-HTML
<div class='code-block'>
  #{download_link(filename)}
  <div class='rendered-code'>
    #{formatted_code}
  </div>
</div>
HTML
  end

  def download_link(filename, display_text = filename)
    %{<a href="#{filename}" download="#{filename}" class="download-link">#{display_text}</a>}
  end

  private

  # This is a bit of a hack to get the full path of a file relative to the
  # current template. There's probably a better way, but this works, and
  # efficiency isn't an issue since it happens only at site build time.
  def guess_full_path(filename)
    # Read the file from the directory that the calling template is in
    # Assume there's one method (from this module) in the callstack before the
    # template
    caller[1] =~ /([^:]*):\d*/
    template = File.basename($1)
    template =~ /([^\.]*)\./
    dir = $1
    File.join(settings.source, "blog", dir, filename)
  end
end
