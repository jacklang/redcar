
class Redcar::EditView
  class AutoPairer
    def self.lookup_autopair_rules
      @autopair_rules = Hash.new {|h, k| h[k] = {}}
      @autopair_default = nil
      start = Time.now
      Redcar::Bundle.names.each do |name|
        prefs = Redcar::Bundle.get(name).preferences
        prefs.each do |pref_name, pref_hash|
          scope = pref_hash["scope"]
          if scope
            pref_hash["settings"].each do |set_name, set_value|
              if set_name == "smartTypingPairs"
                @autopair_rules[scope] = Hash[*set_value.flatten]
              end
            end
          else
            pref_hash["settings"].each do |set_name, set_value|
              if set_name == "smartTypingPairs"
                @autopair_default = Hash[*set_value.flatten]
              end
            end
          end
        end
      end
      if @autopair_default
        @autopair_default1 = @autopair_default.invert
      end
      puts "loaded bundle preferences in #{Time.now - start}s"
      @autopair_rules.default = nil
    end

    def self.autopair_rules_for_scope(current_scope)
      @cache ||= {}
      if rules = @cache[current_scope]
#        p :cached
        return rules
      end
      rules = nil
      if current_scope
        matches = @autopair_rules.map do |scope_name, value|
          if match = Gtk::Mate::Matcher.get_match(scope_name, current_scope)
            [scope_name, match, value]
          end
        end.compact
        best_match = matches.sort do |a, b|
          Gtk::Mate::Matcher.compare_match(current_scope, a[1], b[1])
        end.last
        if best_match
          rules = best_match[2]
        end
      end
#      p :end
#      p rules
      rules = @autopair_default unless rules
      @cache[current_scope] = rules
#      p rules
      rules
    end

    cattr_reader :autopair_rules, :autopair_default, :autopair_default1
    attr_reader  :mark_pairs

    def initialize(buffer)
      self.buffer = buffer
      @parser = buffer.parser
      @mark_pairs = []
      buffer.autopairer = self
    end

    def buffer=(buf)
      @buffer = buf
      connect_buffer_signals
    end

    def add_mark_pair(pair)
      @mark_pairs << pair
#       p :registered_pair
#       p pair.map{|m| @buffer.get_iter_at_mark(m).offset}
      if @mark_pairs.length > 10
        p :Whoah_many_pairs
      end
    end

    # Forget about pairs if the cursor moves from within them
    def invalidate_pairs(mark)
      i = @buffer.get_iter_at_mark(mark)
      @mark_pairs.reject! do |m1, m2|
        i1 = @buffer.get_iter_at_mark(m1)
        i2 = @buffer.get_iter_at_mark(m2)
        if i < i1 or i > i2
          @buffer.delete_mark(m1)
          @buffer.delete_mark(m2)
          true
        end
      end
    end

    def inspect_pairs
      @mark_pairs.map{|mp| mp.map{|m|@buffer.get_iter_at_mark(m).offset}}
    end

    def find_mark_pair_by_start(iter)
      @mark_pairs.find do |m1, m2|
        @buffer.get_iter_at_mark(m1) == iter
      end
    end

    def find_mark_pair_by_end(iter)
      @mark_pairs.find do |m1, m2|
        @buffer.get_iter_at_mark(m2) == iter
      end
    end

    def ignore
      @ignore_mark = true
      @ignore_insert = true
      @ignore_delete = true
      yield
      @ignore_mark = false
      @ignore_insert = false
      @ignore_delete = false
    end

    def connect_buffer_signals
      # record the scope details BEFORE the new text is inserted
      # as the new text could change them. (ex: HTML incomplete.illegal.
      # tag)
      @buffer.signal_connect("insert_text") do |_, iter, text, length|
        if cursor_scope = @buffer.cursor_scope
          current_scope = cursor_scope.hierarchy_names(true)
          # Type over ends
          if @rules = AutoPairer.autopair_rules_for_scope(current_scope)
            inverse_rules = @rules.invert
            if inverse_rules.include? text and !@ignore_insert
              end_mark_pair = find_mark_pair_by_end(iter)
              if end_mark_pair and end_mark_pair[3] == text
                @type_over_end = true
                @buffer.parser.stop_parsing
              end
            end
            # Insert matching ends
            if !@type_over_end and @rules.include? text and !@ignore_insert and !@done
              @insert_end = true
              @buffer.parser.stop_parsing
            end
          end
        end
        false
      end

      @buffer.signal_connect_after("insert_text") do |_, iter, text, length|
        @done = nil
        
        # Type over ends
        if @type_over_end
          @buffer.delete(@buffer.iter(@buffer.cursor_offset-1),
                         @buffer.cursor_iter)
          @buffer.place_cursor(@buffer.iter(@buffer.cursor_offset+1))
          @type_over_end = false
          @buffer.parser.start_parsing
          @done = true
        end

        # Insert matching ends
        if @insert_end and !@ignore_insert
          @ignore_insert = true
          endtext = @rules[text]
          @buffer.insert_at_cursor(endtext)
          @buffer.place_cursor(@buffer.iter(@buffer.cursor_offset-1))
          mark1 = @buffer.create_mark(nil, @buffer.iter(@buffer.cursor_offset-1), false)
          mark2 = @buffer.create_mark(nil, @buffer.cursor_iter, false)
          add_mark_pair [mark1, mark2, text, endtext]
          @ignore_insert = false
          @buffer.parser.start_parsing
          @insert_end = false
        end
        false
      end

      @buffer.signal_connect("delete_range") do |_, iter1, iter2|
        if iter1.offset == iter2.offset-1 and !@ignore_delete
          @deletion = iter1.offset
        end
      end

      @buffer.signal_connect_after("delete_range") do |_, _, _|
        # Delete end if start deleted
        if @deletion and !@ignore_delete
          mark_pair = find_mark_pair_by_start(@buffer.iter(@deletion))
          if mark_pair
            @ignore_delete = true
            i = @buffer.get_iter_at_mark(mark_pair[1])
            @buffer.delete(i, @buffer.iter(i.offset+1))
            @ignore_delete = false
            @mark_pairs.delete(mark_pair)
            @deletion = nil
          end
        end
      end

      @buffer.signal_connect_after("mark_set") do |widget, event, mark|
        if !@ignore_mark 
          if mark == @buffer.cursor_mark
            invalidate_pairs(mark)
          end
        end
      end
    end
  end
end
