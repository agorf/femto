#!/usr/bin/env ruby

require 'io/console'

module Femto
  class Editor
    def initialize(filename)
      @filename  = filename
      data       = read_file_data
      @line_sep  = data["\r\n"] || "\n"
      lines      = data.split(line_sep)
      @buffer    = Buffer.new(lines)
      @cursor    = Cursor.new
      @history   = History.new
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

    attr_reader :buffer, :blank_buffer, :cursor, :history, :line_sep, :filename

    def render
      clear_screen
      print buffer
      ANSI.move_cursor(cursor.row, cursor.col)
    end

    def handle_input
      char = $stdin.getc

      case char
      when "\cq" then quit
      when "\cs" then save
      when "\cp" then up
      when "\cn" then down
      when "\cf" then right
      when "\cb" then left
      when "\ca" then line_home
      when "\ce" then line_end
      when "\ch" then backspace
      when "\cd" then delete
      when "\cu" then delete_before
      when "\ck" then delete_after
      when "\c_" then history_undo
      when "\cr" then history_redo
      when "\r"  then enter
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

      if blank_buffer
        print blank_buffer # overwrite screen with spaces
        ANSI.move_cursor(0, 0)
      end

      blank_lines = buffer.lines.map {|line| ' ' * line.size }
      @blank_buffer = Buffer.new(blank_lines)
    end

    def read_file_data
      if File.exist?(filename)
        File.read(filename)
      else
        ''
      end
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
      with_copy {|b| b.lines[row].slice!(col) }
    end

    def insert_char(char, row, col)
      with_copy do |b|
        b.lines[row] ||= '' # in case the file is empty
        b.lines[row].insert(col, char)
      end
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

    private

    def with_copy
      Buffer.new(lines.map(&:dup)).tap {|b| yield b }
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

      return self if final_line?(buffer)

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

    def final_line?(buffer)
      row == buffer.lines_count - 1
    end

    def end_of_file?(buffer)
      final_line?(buffer) && end_of_line?(buffer)
    end

    def beginning_of_file?
      row == 0 && col == 0
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

begin
  Femto::Editor.open(ARGV.fetch(0))
rescue IndexError
  puts "Usage: #$0 file"
end
