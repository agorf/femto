require 'io/console'

module Femto
  class Editor
    def initialize(filename)
      @filename  = filename
      data       = File.read(filename) rescue ''
      @line_sep  = data["\r\n"] || "\n"
      lines      = data.split(line_sep)
      @buffer    = Buffer.new(lines)
      @cursor    = Cursor.new
      @snapshots = []
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

    attr_reader :buffer, :blank_buffer, :cursor, :snapshots, :line_sep

    def render
      clear_screen
      print buffer
      ANSI.move_cursor(cursor.row, cursor.col)
    end

    def handle_input
      char = $stdin.getc

      case char
      when "\cq" then quit
      when "\cp" then up
      when "\cn" then down
      when "\cf" then right
      when "\cb" then left
      when "\ch" then backspace
      when "\cd" then delete
      when "\cs" then save
      when "\r"  then enter
      when "\c_" then undo
      when "\ca" then line_home
      when "\ce" then line_end
      when "\cu" then delete_before
      when "\ck" then delete_after
      else
        insert_char(char) if char =~ /[[:print:]]/
      end
    end

    def quit
      reset_screen
      exit
    end

    def up
      @cursor = cursor.up(buffer)
    end

    def down
      @cursor = cursor.down(buffer)
    end

    def right
      @cursor = cursor.right(buffer)
    end

    def left
      @cursor = cursor.left(buffer)
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
      open(@filename, 'w') do |f|
        f << data
      end
    end

    def enter
      store_snapshot

      @buffer = buffer.break_line(cursor.row, cursor.col)
      @cursor = cursor.enter(buffer)
    end

    def undo
      return if snapshots.empty?

      @buffer, @cursor = snapshots.pop
    end

    def insert_char(char)
      store_snapshot

      @buffer = buffer.insert_char(char, cursor.row, cursor.col)
      @cursor = cursor.right(buffer)
    end

    def store_snapshot
      snapshots << [buffer, cursor]
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

      if blank_buffer
        print blank_buffer # overwrite screen with spaces
        ANSI.move_cursor(0, 0)
      end

      blank_lines = buffer.lines.map {|line| ' ' * line.size }
      @blank_buffer = Buffer.new(blank_lines)
    end
  end

  class Buffer
    attr_reader :lines

    def initialize(lines)
      @lines = lines
    end

    def to_s
      lines.map {|line| "#{line}\r\n" }.join
    end

    def lines_count
      lines.size
    end

    def line_length(row)
      lines[row].size
    end

    def delete_char(row, col)
      new_lines = dup_lines
      new_lines[row].slice!(col)
      Buffer.new(new_lines)
    end

    def insert_char(char, row, col)
      new_lines = dup_lines
      new_lines[row] ||= '' # in case the file is empty
      new_lines[row].insert(col, char)
      Buffer.new(new_lines)
    end

    def break_line(row, col)
      new_lines = dup_lines
      new_lines[row..row] = [new_lines[row][0...col], new_lines[row][col..-1]]
      Buffer.new(new_lines)
    end

    def delete_before(row, col)
      new_lines = dup_lines
      new_lines[row][0...col] = ''
      Buffer.new(new_lines)
    end

    def delete_after(row, col)
      new_lines = dup_lines
      new_lines[row][col..-1] = ''
      Buffer.new(new_lines)
    end

    def join_lines(row)
      new_lines = dup_lines
      new_lines[row..row + 1] = new_lines[row..row + 1].join
      Buffer.new(new_lines)
    end

    private

    def dup_lines
      lines.map(&:dup)
    end
  end

  class Cursor
    attr_reader :row, :col

    def initialize(row = 0, col = 0)
      @row = row
      @col = col
    end

    def up(buffer)
      Cursor.new(row - 1, col).clamp(buffer)
    end

    def down(buffer)
      Cursor.new(row + 1, col).clamp(buffer)
    end

    def right(buffer)
      return Cursor.new(row, col + 1) unless end_of_line?(buffer)

      return self if end_of_file?(buffer)

      Cursor.new(row + 1, 0)
    end

    def left(buffer)
      return Cursor.new(row, col - 1) if col > 0

      return self if row == 0

      Cursor.new(row - 1, buffer.line_length(row - 1))
    end

    def clamp(buffer)
      @row = row.clamp(0, buffer.lines_count - 1)
      @col = col.clamp(0, buffer.line_length(row))
      self
    end

    def enter(buffer)
      down(buffer).line_home
    end

    def line_home
      Cursor.new(row, 0)
    end

    def line_end(buffer)
      Cursor.new(row, buffer.line_length(row))
    end

    def end_of_line?(buffer)
      col == buffer.line_length(row)
    end

    def end_of_file?(buffer)
      row == buffer.lines_count - 1 && end_of_line?(buffer)
    end

    def beginning_of_file?
      row == 0 && col == 0
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

Femto::Editor.open(ARGV[0])
