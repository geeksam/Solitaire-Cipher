require 'minitest/autorun'
require File.join(File.dirname(__FILE__), *%w[solitaire])

# This was named #run, but that conflicted with a Minitest method, apparently.  Oops!
def r(range)
  range.to_a
end

describe Solitaire do
  #(fold)
  # 1. Key the deck. This is the critical step in the actual operation of the cipher and the heart
  #    of its security. There are many methods to go about this, such as shuffling a deck and
  #    then arranging the receiving deck in the same order or tracking a bridge column in the
  #    paper and using that to order the cards. Because we want to be able to test our answers
  #    though, we'll use an unkeyed deck, cards in order of value. That is, from top to bottom,
  #    we'll always start with the deck:
  # 
  # Ace of Clubs
  # ...to...
  # King of Clubs
  # Ace of Diamonds
  # ...to...
  # King of Diamonds
  # Ace of Hearts
  # ...to...
  # King of Hearts
  # Ace of Spades
  # ...to...
  # King of Spades
  # "A" Joker
  # "B" Joker
  #(end)
  before :each do
    @sol = Solitaire.new(UNKEYED_DECK)
  end

  # 1. Discard any non A to Z characters, and uppercase all remaining letters. Split the message
  #    into five character groups, using Xs to pad the last group, if needed. If we begin with the
  #    message "Code in Ruby, live longer!", for example, we would now have:
  # 
  # CODEI NRUBY LIVEL ONGER
  CLEARTEXT_1 = "Code in Ruby, live longer!"
  CHUNKED_TEXT_1 = 'CODEI NRUBY LIVEL ONGER'

  describe 'Plaintext chunking' do
    it 'uppercases' do
      assert_equal 'FOOBA', @sol.chunk('fooba')
    end
    
    it 'discards non-alpha chars' do
      assert_equal 'BARFO', @sol.chunk('bar 42!!1! fo!')
    end
    
    it 'chunks messages longer than five characters' do
      assert_equal 'HELLO WORLD', @sol.chunk('Hello, world!')
      assert_equal CHUNKED_TEXT_1, @sol.chunk(CLEARTEXT_1)
    end
    
    it 'pads the last chunk to five characters with Xs' do
      assert_equal 'FOOBA RXXXX', @sol.chunk('foo bar')
    end
  end

  # 2. Use Solitaire to generate a keystream letter for each letter in the message.
  UNKEYED_DECK = (1..52).to_a + [:A, :B]
  
  describe 'Keystream generation' do
    # Here's a key sentence I missed: "Either joker values at 53."
    it 'should value cards correctly' do
      assert_equal 2, @sol.card_number(2)
      assert_equal 52, @sol.card_number(52)
      assert_equal 53, @sol.card_number(:A)
      assert_equal 53, @sol.card_number(:B)
    end
    
    # 2. Move the A joker down one card. If the joker is at the bottom of the deck, move it to just
    #    below the first card. (Consider the deck to be circular.) The first time we do this, the
    #    deck will go from:
    # 1 2 3 ... 52 A B
    # To:
    # 1 2 3 ... 52 B A
    it 'can move the A joker down one card' do
      expected = r(1..52) + [:B, :A]
      @sol.move_joker_down(:A)
      assert_equal expected, @sol.keydeck
    end

    it "can move the A joker to the top if it's at the bottom" do
      expected = [:A] + r(1..52) + [:B]
      @sol.move_joker_down(:A)
      @sol.move_joker_down(:A)
      assert_equal expected, @sol.keydeck
    end

    # 3. Move the B joker down two cards. If the joker is the bottom card, move it just below the
    #    second card. If the joker is the just above the bottom card, move it below the top card.
    #    (Again, consider the deck to be circular.) This changes our example deck to:
    # 1 B 2 3 4 ... 52 A
    it 'can move the B joker down two cards' do
      expected = [1, :B] + r(2..52) + [:A]
      @sol.move_joker_down(:B)
      assert_equal expected, @sol.keydeck
    end
    
    it 'will not move the B joker to the top of the deck' do
      expected = [1, :B] + r(2..52) + [:A]
      @sol.move_joker_down(:A)
      @sol.move_joker_down(:B)
      assert_equal expected, @sol.keydeck
    end
    
    # 4. Perform a triple cut around the two jokers. All cards above the top joker move to below
    #    the bottom joker and vice versa. The jokers and the cards between them do not move. This
    #    gives us:
    # B 2 3 4 ... 52 A 1
    it 'can perform the given triple cut' do
      expected = [:B] + r(2..52) + [:A, 1]
      @sol.move_joker_down(:B)
      @sol.triple_cut
      assert_equal expected, @sol.keydeck
    end
    
    it 'can perform another triple cut on a simpler deck' do
      @sol.keydeck = [1, 2, 3, :A, 4, 5, 6, :B, 7, 8, 9]
      expected     = [7, 8, 9, :A, 4, 5, 6, :B, 1, 2, 3]
      @sol.triple_cut
      assert_equal expected, @sol.keydeck
    end

    # 5. Perform a count cut using the value of the bottom card. Cut the bottom card's value in
    #    cards off the top of the deck and reinsert them just above the bottom card. This changes
    #    our deck to:
    # 2 3 4 ... 52 A B 1  (the 1 tells us to move just the B)
    it 'can perform a count cut' do
      expected = r(2..52) + [:A, :B, 1]
      @sol.move_joker_down(:B)
      @sol.triple_cut
      @sol.count_cut
      assert_equal expected, @sol.keydeck
    end

    it 'can perform a count cut on a simpler deck' do
      @sol.keydeck = [7, 8, 9, :A, 4, 5, 6, :B, 1, 2, 3]
      expected     = [:A, 4, 5, 6, :B, 1, 2, 7, 8, 9, 3]
      @sol.count_cut
      assert_equal expected, @sol.keydeck
    end

    # 6. Find the output letter. Convert the top card to it's value and count down that many cards
    #    from the top of the deck, with the top card itself being card number one. Look at the card
    #    immediately after your count and convert it to a letter. This is the next letter in the
    #    keystream. If the output card is a joker, no letter is generated this sequence. This step
    #    does not alter the deck. For our example, the output letter is:
    # D  (the 2 tells us to count down to the 4, which is a D)
    it 'can generate the given output letter from the given deck' do
      @sol.move_joker_down(:B)
      @sol.triple_cut
      @sol.count_cut
      assert_equal 'D', @sol.output_letter
    end
    
    it 'can generate an output letter from a simple deck' do
      @sol.keydeck = [2, nil, 7]
      assert_equal 'G', @sol.output_letter
    end
    
    it 'does not generate an output letter when output card is a joker' do
      @sol.keydeck = [1, :B]
      assert_nil @sol.output_letter
    end

    # 7. Return to step 2, if more letters are needed.
    # For the sake of testing, the first ten output letters for an unkeyed deck are:
    # D (4)  W (49)  J (10)  Skip Joker (53)  X (24)  H (8)
    # Y (51)  R (44)  F (6)  D (4)  G (33)
    it 'produces the above sequence one at a time' do
      @sol.iterate; assert_equal 'D', @sol.output_letter
      @sol.iterate; assert_equal 'W', @sol.output_letter
      @sol.iterate; assert_equal 'J', @sol.output_letter
      @sol.iterate; assert_nil @sol.output_letter
      @sol.iterate; assert_equal 'X', @sol.output_letter
      @sol.iterate; assert_equal 'H', @sol.output_letter

      @sol.iterate; assert_equal 'Y', @sol.output_letter
      @sol.iterate; assert_equal 'R', @sol.output_letter
      @sol.iterate; assert_equal 'F', @sol.output_letter
      @sol.iterate; assert_equal 'D', @sol.output_letter
      @sol.iterate; assert_equal 'G', @sol.output_letter
    end
    
    it 'produces a keystream that matches the length of the given input' do
      assert_equal 'DWJXH YRFDG', @sol.keystream('HELLO WORLD')
    end
  end

  # 3. Convert the message from step 1 into numbers, A = 1, B = 2, etc:
  # 
  # 3 15 4 5 9  14 18 21 2 25  12 9 22 5 12  15 14 7 5 18
  describe "Encoding of chunked text" do
    it "works" do
      expected = [
        3, 15, 4, 5, 9,
        14, 18, 21, 2, 25,
        12, 9, 22, 5, 12,
        15, 14, 7, 5, 18
      ]
      assert_equal expected, @sol.encode_chunks(CHUNKED_TEXT_1)
    end
  end

  # 4. Convert the keystream letters from step 2 using the same method:
  # 
  # 4 23 10 24 8  25 18 6 4 7  20 13 19 8 16  21 21 18 24 10
  # 
  # 5. Add the message numbers from step 3 to the keystream numbers from step 4 and subtract 26
  #    from the result if it is greater than 26. For example, 6 + 10 = 16 as expected, but 26 + 1 =
  #    1 (27 - 26):
  # 
  # 7 12 14 3 17  13 10 1 6 6  6 22 15 13 2  10 9 25 3 2
  # 
  # 6. Convert the numbers from step 5 back to letters:
  # 
  # GLNCQ MJAFF FVOMB JIYCB
end
