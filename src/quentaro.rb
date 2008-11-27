#!/usr/bin/ruby

require 'Qt4'


class Highlighter < Qt::SyntaxHighlighter
  def initialize(parent = nil)
    super
    @patterns = {}
  end

  def clear(type)
    @patterns[type] = {}
    rehighlight
  end

  def add_highlight(type, text, color)
    @patterns[type] = Hash.new unless @patterns.key?(type)
    @patterns[type][text] = color
#    rehighlight
  end

  def highlightBlock(text)
    @patterns.each do |type, specs|
      specs.each {|pattern, color| highlightColor(text, pattern, color)}
    end
  end

  def highlightColor(text, pattern, color)
    myClassFormat = Qt::TextCharFormat.new
    myClassFormat.setBackground(Qt::Brush.new(color))

    # Use Qt matcher to support UTF-8 encoding
    matcher = Qt::RegExp.new(pattern, Qt::CaseInsensitive)
    index = matcher.indexIn(text)
    until index < 0
      length = matcher.matchedLength
      setFormat(index, length, myClassFormat)
      index = matcher.indexIn(text, index + length)
    end
  end
end


class AntiRepetition < Qt::Widget

  attr_reader :repetitions


  def initialize(text)
    super()
    @text = text
    @dict = {}

    @threshold = 8

    parse
  end

  def parse
    @wordtotal = 0
    @text.scan(/\w+/) do |word|
      next if word.size < 3
      @dict[word] = [] unless @dict.key?(word)
      @dict[word].push(@wordtotal)  # record position

      @wordtotal += 1
    end

    # FIXME: compute intervals, factor
    @repetitions = {}
    @dict.each do |word, positions|
      next if positions.size < 2

      @repetitions[word] = []
      i = 1
      while i < positions.size
        if positions[i] - positions[i - 1] < @threshold
          @repetitions[word].push(positions[i - 1])
          @repetitions[word].push(positions[i])
        end
        i += 1
      end

      @repetitions.delete(word) if @repetitions[word].empty?
    end
  end

  def each_repetition

  end
end


class Quentaro < Qt::Widget

  slots 'run(const QString&)', 'pick()', 'find()'

  def initialize
    super

    @search_input = Qt::LineEdit.new
    @text = Qt::TextEdit.new
    @text.readOnly = true

    @highlighter = Highlighter.new(@text)

    # Read a demo file
    fp = Qt::File.new("../../write/stories/shibuya/shibuya.txt")
    fp.open(Qt::IODevice::ReadOnly | Qt::IODevice::Text)
    stream = Qt::TextStream.new(fp)
    until stream.atEnd
      @text.append(stream.readLine)
    end
    fp.close

    ar = AntiRepetition.new(@text.plainText)
    ar.repetitions.each do |word, positions|
      cr = rand(255)
      cg = rand(255)
      cb = rand(255)
      puts "#{word} - #{positions[0]}"
      @highlighter.add_highlight(:repetition, word, Qt::Color.new(cr, cg, cb))
    end
    puts "DONE"
    @highlighter.rehighlight

    connect(@search_input, SIGNAL('textChanged(const QString&)'), self, SLOT('run(const QString&)'))
    connect(@text, SIGNAL('cursorPositionChanged()'), self, SLOT('pick()'))

    shortcut_find = Qt::Shortcut.new(Qt::KeySequence.new(Qt::CTRL + Qt::Key_F), self)
    connect(shortcut_find, SIGNAL('activated()'), self, SLOT('find()'))

    @search_input.visible = false

    layout = Qt::VBoxLayout.new
    layout.addWidget(@text)
    layout.addWidget(@search_input)
    setLayout(layout)
  end

  def run(input)
    @highlighter.clear(:match)
    @highlighter.add_highlight(:match, input, Qt::Color.new(180, 180, 255)) unless input.empty?
  end

  def pick
    curs = @text.textCursor
    curs.select(Qt::TextCursor::WordUnderCursor)
    text = curs.selection.toPlainText

    @highlighter.clear(:cursor)
    @highlighter.add_highlight(:cursor, text, Qt::Color.new(255, 255, 150)) unless text.nil?
  end

  def find
    if @search_input.visible
      @search_input.selectAll
    else
      @search_input.visible = true
      @search_input.setFocus(Qt::ShortcutFocusReason)
    end
  end
end
