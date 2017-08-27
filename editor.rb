require 'io/console'

class Editor
  def initialize(filename)
    @filename  = filename
    data       = File.read(filename)
    @line_sep  = data["\r\n"] || "\n"
    lines      = data.split(@line_sep)
    @buffer    = Buffer.new(lines)
    @cursor    = Cursor.new
    @snapshots = []
  end

  def run
    IO.console.raw do
      loop do
        render
        handle_input
      end
    end
  end

  def render
    ANSI.move_cursor(0, 0)
    ANSI.clear_screen
    @buffer.print
    ANSI.move_cursor(@cursor.row, @cursor.col)
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
    else
      insert_char(char) if char =~ /[[:print:]]/
    end
  end

  def quit
    ANSI.clear_screen
    exit
  end

  def up
    @cursor = @cursor.up(@buffer)
  end

  def down
    @cursor = @cursor.down(@buffer)
  end

  def right
    @cursor = @cursor.right(@buffer)
  end

  def left
    @cursor = @cursor.left(@buffer)
  end

  def backspace
    return if @cursor.col == 0

    store_snapshot

    @buffer = @buffer.delete_char(@cursor.row, @cursor.col - 1)
    @cursor = @cursor.left(@buffer)
  end

  def delete
    store_snapshot

    @buffer = @buffer.delete_char(@cursor.row, @cursor.col)
  end

  def save
    open(@filename, 'w') do |f|
      f << @buffer.data(@line_sep)
    end
  end

  def enter
    store_snapshot

    @buffer = @buffer.break_line(@cursor.row, @cursor.col)
    @cursor = @cursor.enter(@buffer)
  end

  def undo
    return if @snapshots.empty?

    @buffer, @cursor = @snapshots.pop
  end

  def insert_char(char)
    store_snapshot

    @buffer = @buffer.insert_char(char, @cursor.row, @cursor.col)
    @cursor = @cursor.right(@buffer)
  end

  def store_snapshot
    @snapshots << [@buffer, @cursor]
  end

  def line_home
    @cursor = @cursor.line_home(@buffer)
  end

  def line_end
    @cursor = @cursor.line_end(@buffer)
  end
end

class Buffer
  attr_reader :lines

  def initialize(lines)
    @lines = lines
  end

  def print
    lines.each do |line|
      $stdout.print "#{line}\r\n"
    end
  end

  def data(line_sep)
    data = lines.join(line_sep).chomp(line_sep)
    data << line_sep unless data.empty?
    data
  end

  def lines_count
    lines.size
  end

  def line_length(row)
    lines[row].size
  end

  def delete_char(row, col)
    dup_lines = lines.map(&:dup)
    dup_lines[row].slice!(col)
    Buffer.new(dup_lines)
  end

  def insert_char(char, row, col)
    dup_lines = lines.map(&:dup)
    dup_lines[row].insert(col, char)
    Buffer.new(dup_lines)
  end

  def break_line(row, col)
    dup_lines = lines.map(&:dup)
    dup_lines[row..row] = [dup_lines[row][0...col], dup_lines[row][col..-1]]
    Buffer.new(dup_lines)
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
    Cursor.new(row, col + 1).clamp(buffer)
  end

  def left(buffer)
    Cursor.new(row, col - 1).clamp(buffer)
  end

  def clamp(buffer)
    @row = row.clamp(0, buffer.lines_count - 1)
    @col = col.clamp(0, buffer.line_length(row))
    self
  end

  def enter(buffer)
    Cursor.new(row + 1, 0).clamp(buffer)
  end

  def line_home(buffer)
    Cursor.new(row, 0).clamp(buffer)
  end

  def line_end(buffer)
    Cursor.new(row, buffer.line_length(row)).clamp(buffer)
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

Editor.new(ARGV[0]).run
