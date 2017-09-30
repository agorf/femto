#!/usr/bin/env ruby

require 'io/console'

# TODO remove?
unless Comparable.instance_methods.include?(:clamp)
  class Fixnum
    def clamp(min, max)
      if min > max
        raise ArgumentError, 'min argument must be smaller than max argument'
      end

      return min if self <= min
      return max if self >= max
      self
    end
  end
end

module Femto
  class Editor
    def initialize(filename)
      @filename = filename
      data      = read_file_data
      @line_sep = data["\r\n"] || "\n"
      @buffer   = Buffer.new(lines_from_data(data))
      @cursor   = Cursor.new
      @history  = History.new
    end

    def self.open(filename)
      new(filename).run
    end

    def run
      IO.console.raw do
        reset_screen

        loop do
          render
          handle_input
        end
      end
    end

    private

    attr_reader :buffer, :cursor, :history, :line_sep, :filename

    def render
      clear_screen
      print buffer
      ANSI.move_cursor(cursor.row, cursor.col)
    end

    def handle_input
      char = read_char

      case char
      when "\cq" then quit
      when "\cs" then save
      when "\cp", "\e[A" then up
      when "\cn", "\e[B" then down
      when "\cf", "\e[C" then right
      when "\cb", "\e[D" then left
      when "\ca", "\e[7~" then line_home
      when "\ce", "\e[8~" then line_end
      when "\ch", "\177" then backspace
      when "\cd", "\e[3~", "\004" then delete
      when "\cu" then delete_before
      when "\ck" then delete_after
      when "\c_" then history_undo
      when "\cr" then history_redo
      when "\r"  then enter
      else
        insert_char(char) if char =~ /[[:print:]]/
      end
    end

    def read_char
      char = $stdin.getc

      return char if char != "\e"

      maxlen = 3

      begin
        char << $stdin.read_nonblock(maxlen)
      rescue IO::WaitReadable
        return char if maxlen == 2

        maxlen -= 1
        retry
      end

      char
    end

    def quit
      reset_screen
      exit
    end

    def up
      bufcur = BufferCursor.new(buffer, cursor)

      return if bufcur.first_line?

      if bufcur.top_edge?
        @buffer = buffer.scroll_up
      else
        @cursor = cursor.up
      end
    end

    def down
      bufcur = BufferCursor.new(buffer, cursor)

      return if bufcur.last_line?

      if bufcur.bottom_edge?
        @buffer = buffer.scroll_down
      else
        @cursor = cursor.down
      end

      #buffer.offset_x = [buffer.row_length(cursor.row) - buffer.cols + 1, 0].max
      #@cursor.col = buffer.row_length(cursor.row) - buffer.offset_x # FIXME
    end

    def right
      bufcur = BufferCursor.new(buffer, cursor)

      if bufcur.end_of_line?
        unless bufcur.last_line?
          down
          line_home
        end
      elsif cursor.col == buffer.cols - 1
        max_offset_x = buffer.row_length(cursor.row) - buffer.cols + 1

        if max_offset_x > 0
          if buffer.offset_x < max_offset_x
            @buffer = buffer.right
          end
        end
      else
        @cursor = cursor.right
      end
    end

    def left
      #return Cursor.new(row, col - 1) if col > 0
      #return self if row == 0
      #Cursor.new(row - 1, buffer.line_length(row - 1))
      if cursor.col == 0
        if buffer.offset_x > 0
          @buffer = buffer.left
        end
      else
        @cursor = cursor.left
      end

      #@cursor = cursor.clamp(buffer)
    end

    def backspace
      return if cursor.beginning_of_file?

      store_snapshot

      if cursor.col == 0
        cursor_left = buffer.lines[cursor.row].size + 1
        @buffer = buffer.join_lines(cursor.row - 1)
        cursor_left.times { @cursor = cursor.left(buffer) }
      else
        @buffer = buffer.delete_char(cursor.row, cursor.col - 1)
        @cursor = cursor.left(buffer)
      end
    end

    def delete
      return if cursor.end_of_file?(buffer)

      store_snapshot

      if cursor.end_of_line?(buffer)
        @buffer = buffer.join_lines(cursor.row)
      else
        @buffer = buffer.delete_char(cursor.row, cursor.col)
      end
    end

    def data
      data = buffer.lines.join(line_sep).chomp(line_sep)
      data << line_sep unless data.empty?
      data
    end

    def save
      open(filename, 'w') {|f| f << data }
    end

    def enter
      store_snapshot

      @buffer = buffer.break_line(cursor.row, cursor.col)
      @cursor = cursor.enter(buffer)
    end

    def history_undo
      return unless history.can_undo?

      store_snapshot(false) unless history.can_redo?

      @buffer, @cursor = history.undo
    end

    def history_redo
      return unless history.can_redo?

      @buffer, @cursor = history.redo
    end

    def insert_char(char)
      store_snapshot

      @buffer = buffer.insert_char(char, cursor.row, cursor.col)
      @cursor = cursor.right(buffer)
    end

    def store_snapshot(advance = true)
      history.save([buffer, cursor], advance)
    end

    def line_home
      @cursor = cursor.line_home
    end

    def line_end
      @cursor = cursor.line_end(buffer)
    end

    def delete_before
      store_snapshot

      @buffer = buffer.delete_before(cursor.row, cursor.col)
      line_home
    end

    def delete_after
      store_snapshot

      @buffer = buffer.delete_after(cursor.row, cursor.col)
    end

    def reset_screen
      ANSI.move_cursor(0, 0)
      ANSI.clear_screen
    end

    def clear_screen
      ANSI.move_cursor(0, 0)

      # Overwrite screen with spaces
      Buffer::ROWS.times do
        print (' ' * Buffer::COLS) << "\r\n"
      end

      ANSI.move_cursor(0, 0)
    end

    def read_file_data
      if File.exist?(filename)
        File.read(filename)
      else
        ''
      end
    end

    def lines_from_data(data)
      if data.empty?
        ['']
      else
        data.split(line_sep)
      end
    end
  end

  class Buffer
    ROWS = 20 # TODO screen
    COLS = 40 # TODO screen

    attr_reader :lines, :offset_x, :offset_y
    attr_writer :offset_x

    def initialize(lines, offset_x = 0, offset_y = 0)
      @lines = lines
      @offset_x = offset_x
      @offset_y = offset_y
    end

    def to_s
      lines[offset_y...offset_y + ROWS].map {|line|
        "#{line[offset_x...offset_x + COLS]}\r\n"
      }.join
    end

    def lines_count
      lines.size
    end

    # TODO make private?
    def line_length(row)
      lines[row].size
    end

    def delete_char(row, col)
      with_copy {|b| b.lines[row].slice!(col) }
    end

    def insert_char(char, row, col)
      with_copy {|b| b.lines[row].insert(col, char) }
    end

    def break_line(row, col)
      with_copy do |b|
        b.lines[row..row] = [b.lines[row][0...col], b.lines[row][col..-1]]
      end
    end

    def delete_before(row, col)
      with_copy {|b| b.lines[row][0...col] = '' }
    end

    def delete_after(row, col)
      with_copy {|b| b.lines[row][col..-1] = '' }
    end

    def join_lines(row)
      with_copy {|b| b.lines[row..row + 1] = b.lines[row..row + 1].join }
    end

    def scroll_up
      with_copy(offset_x, offset_y - 1)
    end

    def scroll_down
      with_copy(offset_x, offset_y + 1)
    end

    def right
      with_copy(offset_x + 1, offset_y)
    end

    def left
      with_copy(offset_x - 1, offset_y)
    end

    # TODO keep?
    def cols
      COLS
    end

    # TODO keep?
    def rows
      ROWS
    end

    # TODO rename?
    def row_length(row)
      line_length(offset_y + row)
    end

    def max_offset_y
      lines_count - rows
    end

    private

    def with_copy(*args)
      Buffer.new(lines.map(&:dup), *args).tap {|b|
        yield b if block_given?
      }
    end
  end

  class Cursor
    attr_reader :row, :col
    attr_writer :col

    def initialize(row = 0, col = 0)
      @row = row
      @col = col
    end

    def up
      Cursor.new(row - 1, col)
    end

    def down
      Cursor.new(row + 1, col)
    end

    def right
      Cursor.new(row, col + 1)
    end

    def left
      Cursor.new(row, col - 1)
    end

    # TODO
    def clamp!(rows, cols)
      @row = row.clamp(0, rows)
      @col = col.clamp(0, cols)
      self
    end

    def enter(buffer)
      down(buffer).line_home # FIXME
    end

    # TODO
    def line_home
      Cursor.new(row, 0)
    end

    # TODO
    def line_end(buffer)
      Cursor.new(row, buffer.line_length(row))
    end

    # TODO
    def end_of_line?(buffer)
      col == buffer.line_length(row)
    end

    # TODO
    def final_line?(buffer)
      row == buffer.lines_count - 1
    end

    # TODO
    def end_of_file?(buffer)
      final_line?(buffer) && end_of_line?(buffer)
    end

    # TODO
    def beginning_of_file?
      row == 0 && col == 0
    end
  end

  class BufferCursor
    attr_reader :buffer, :cursor

    def initialize(buffer, cursor)
      @buffer = buffer
      @cursor = cursor
    end

    def first_line?
      row == 0
    end

    def last_line?
      row == buffer.lines_count - 1
    end

    def end_of_line?
      col == buffer.line_length(row)
    end

    def top_edge?
      cursor.row == 0
    end

    def bottom_edge?
      cursor.row == buffer.rows - 1
    end

    private

    def row
      buffer.offset_y + cursor.row
    end

    def col
      buffer.offset_x + cursor.col
    end
  end

  class History
    def initialize
      @snapshots = []
      @current = -1
    end

    def save(data, advance = true)
      snapshots.slice!(current + 1..-1) # branching; purge redo history

      snapshots << data
      @current += 1 if advance
    end

    def can_undo?
      !undo_snapshot.nil?
    end

    def undo
      undo_snapshot.tap { @current -= 1 }
    end

    def can_redo?
      !redo_snapshot.nil?
    end

    def redo
      redo_snapshot.tap { @current += 1 }
    end

    private

    attr_reader :snapshots, :current

    def undo_snapshot
      snapshots[current] if current >= 0
    end

    def redo_snapshot
      snapshots[current + 2]
    end
  end

  module ANSI
    def self.clear_screen
      print "\e[J"
    end

    def self.move_cursor(row, col)
      print "\e[#{row + 1};#{col + 1}H"
    end
  end
end

if __FILE__ == $0
  begin
    Femto::Editor.open(ARGV.fetch(0))
  rescue IndexError
    puts "Usage: #$0 file"
  end
end
