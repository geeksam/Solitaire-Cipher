class Solitaire
  ALPHABET = ('A'..'Z').to_a

  def initialize(keydeck)
    @keydeck = keydeck.dup # Avoid side effects in tests!
  end

  attr_writer :keydeck
  def keydeck
    @keydeck.dup
  end

  def chunk(text)
    text.
      upcase.
      gsub(/[^A-Z]/, '').
      scan(/.{0,5}/).
      reject(&:empty?).
      map { |e| e + 'X' * (5 - e.length) }.
      join(' ')
  end

  def encode_chunks(chunked_text)
    chunked_text.split(' ').join.split(//).map { |e| ALPHABET.index(e) + 1 }
  end

  def keystream(chunked_text)
    chunked_text.split(//).map { |e| ' ' == e ? ' ' : next_output_letter }.join
  end

  # These methods are concerned with keystream generation

  def move_joker_down(joker)
    raise "wtf?" unless [:A, :B].include?(joker)
    offset = :A == joker ? 1 : 2
    offset.times do
      if joker == @keydeck.last
        @keydeck.unshift(@keydeck.pop)
      else
        i = @keydeck.index(joker)
        @keydeck[i], @keydeck[i + 1] = @keydeck[i + 1], @keydeck[i]
      end
    end
    if joker == :B && joker == @keydeck.first
      @keydeck[0], @keydeck[1] = @keydeck[1], @keydeck[0]
    end
  end

  def triple_cut
    i1, i2 = *([@keydeck.index(:A), @keydeck.index(:B)].sort)
    i2 += 1

    mid = @keydeck.dup
    top, bot = [], []
    top << mid.shift     until mid.first.kind_of?(Symbol)
    bot.unshift(mid.pop) until mid.last.kind_of?(Symbol)
    
    @keydeck = bot + mid + top
  end

  def count_cut
    bottom_card = @keydeck.pop
    cards_from_top = @keydeck.slice!(0..(card_number(bottom_card)-1))
    @keydeck = @keydeck + cards_from_top + [bottom_card]
  end

  def output_letter
    n = card_number(@keydeck.first)  
    # this sometimes returns 54, which seems wrong.
    # Should the B joker ever be at the top of the deck?
    output_number = @keydeck[n]
    # if output_number.nil?
    #   puts ''
    #   puts n
    #   puts card_number(@keydeck[n-1])
    #   debug
    #   return
    # end
    # return if output_number.kind_of?(Symbol)
    card_letter(output_number)
    # ALPHABET[(output_number - 1) % 26]
  end

  def iterate
    move_joker_down :A
    move_joker_down :B
    triple_cut
    count_cut
  end

  def next_output_letter
    loop do
      iterate
      break unless output_letter.nil?
    end
    output_letter
  end

  def card_number(card)
    case card
    when Symbol then 53
    when :B then 54
    else card
    end
  end

  def card_letter(card)
    case card
    when Symbol then nil
    else ALPHABET[(card_number(card) - 1) % 26]
    end
  end

  def debug(msg = nil)
    puts msg if msg
    puts @keydeck.join(' ')
  end
end
