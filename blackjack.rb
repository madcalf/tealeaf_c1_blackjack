# Course 1. Lesson 1. Blackjack (procedural)

# The following ASCII / Unicode symbols are copied from here
#   http://en.wikipedia.org/wiki/Playing_cards_in_Unicode
#   ♤ ♡ ♢ ♧
#   U+2664 (9828dec)  U+2661 (9825dec)  U+2662 (9826dec)  U+2667 (9831dec)
#   Here they're pasted, but can also draw them using the unicode hex val 
#     as follows: "\u2664" or "\u{2264}". 
#   Not sure how to use the decimal versions

require 'pry'

FACES = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
SUITS = [{'C' => '♧'}, {'D' => '♢'}, {'H' => '♡'}, {'S' => '♤'}]
# unicode numbers, just for reference
# SUITS = [{'C' => "\u2663"}, {'D' => "\u2666"}, {'H' => "\u2665"}, {'S' => "\u2660"}]

# for drawing
SPACE =     " "
HASH = "-"
WIDESPACE = "  "
WIDECOLON = "･"
WIDEPIPE = "｜"
PIPE = "|"
# halfwidth filler from korean hangul. 
# using it here to compensate for the extra width of suit symbols
# only seems to work at the beginning of a line tho...
HF = "ﾠﾠﾠﾠ\u{FFA0}" 

# ==================== METHODS ====================

def numeric?(str) 
  # using Float this way seems to be a popular way to do this on SO
  # anything wrong with it? 
  # is it ok to rely on an exception to set a value?
  begin 
    result = Float(str) ? true : false
  rescue
    result = false
  ensure
    return result
  end
end

def make_deck
  deck = []
  card = {}
  SUITS.each do |suit|
    FACES.each do |face|
      deck.push(make_card(suit, face)) 
    end
  end  
  return deck 
end
    
def make_card(suit, face)
  card = {}
  # suit is a hash with only one value
  card = {face: face, suit: suit.keys[0], values:nil, symbol:suit.values[0], is_face_up: true}
  if numeric?(face)
    card[:values] = [face.to_i]
  else
    card[:values] = (face == 'A') ? [1, 11] : [10]
  end
  puts "card: #{card}"
  return card 
end

def get_card(gd) 
  gd[:deck].sample
end

# deals specified card, for testing specifics without waiting for it
#   to happen randomly
def deal_test_card(gd, which_player, face, suit = nil)
  # if no suit is specified pick a random card with specified face value
  cards = gd[:deck].select { |card| card[:face] == face}
  if suit
    card = cards.select { |card| card[:suit] == suit }[0] 
  else
    card = cards.sample
  end
  which_player[:hand][:cards].push(card)
  update_hand_value(gd, which_player)
end

def deal_card(gd, which_player, is_face_up = true)
  card = get_card(gd)
  card[:is_face_up] = is_face_up
  which_player[:hand][:cards].push(card)
  update_hand_value(gd, which_player)
end

def start_game(gd)
  puts "Dealing..."
  sleep 1
  draw(gd)
  sleep 1
  gd[:state] = :deal
  # deal player cards first
  2.times do 
    deal_card(gd, gd[:player])
    draw(gd)
    sleep 1
  end
  
  # # TEMP - for testing
  # deal_test_card(gd, gd[:player], "A")
  # draw(gd)
  # sleep 1
  # deal_card(gd, gd[:player])
  # draw(gd)
  # sleep 1
  
  
  sleep 1 # slight pause before doing dealer
  # note: dealer's first card goes face down  
  2.times do |i|
    is_face_up = (i == 0) ? false : true
    deal_card(gd, gd[:dealer], is_face_up)
    draw(gd)
    sleep 1
  end
end

def update_hand_value(gd, which_player)
  hand = which_player[:hand]
  # if there's an Ace, this hand will have 2 totals
  cards = hand[:cards]
  if cards.size == 1
    # there's only one card so just get the face value or the max if it's an Ace
    value = cards[0][:values].max
  else
    # note if there's an ace, card[:values] will have 2 items: [1, 11] 
    #   otherwise it will have one: [9]
       
    # collect an array of all card's values in this hand
    values = cards.map { |card| card[:values]}
    puts "values: #{values}"
    # get the cross product of the first card's value(s) & the remaining ones
    #   this turns multiple arrays from this [[10], [3], [4]] to this: [[10, 3, 4]]  
    #   With an Ace it looks more like [[1, 11], [5], [3]] => [[1, 5, 3], [11, 5, 3]]
    #   note we need use the splat (*) so we pass the inner arrays as args
    product = values.first.product(*values.drop(1))
    # sum up the totals of each resulting array. The result is an array of sums 
    #   e.g. [8, 18]
    sums = product.map do |arr|
      arr.reduce(:+)
    end
    # If there's 2 Aces, we'll have more than 2 sums, but one will be a duplicate
    #   and the the other will exceed 21, so we eliminate them here
    sums.uniq.select { |item| item <= 21}
    puts "sums: #{sums}"
    # if there are 2 sums, display both, otherwise just the one
    value = sums.size == 1 ? "#{sums[0]}" : "#{sums.min}/#{sums.max}"
  end
  hand[:value] = value
  # binding.pry
end

# def update_hand_value(gd, which_player)
#   hand = which_player[:hand]
#   # if there's an Ace, this hand will have 2 totals
#   cards = hand[:cards]
#   if cards.size == 1
#     # there's only one card so just get the face value or the max if it's an Ace
#     value = cards[0][:values].max
#   elsif has_ace(hand)
#     # need to compute multiple hand values since A can be 1 or 11
#     puts "Hand has an Ace!!"
#     # use drop_while to get non aces, but this would remove all of them?
#     values = cards.map { |card| card[:values]}
#     puts "values: #{values}"
#     # get the cross product of the first array and the remaining ones
#     #   this turns something like [1, 11], [5], [3] into this: [[1, 5, 3], [11, 5, 3]]
#     #   note we need use the splat (*) so we pass the inner arrays as args
#     product = values.first.product(*values.drop(1))
#     # sum up the totals of each resulting array. The result is an array of sums 
#     #   e.g. [8, 18]
#     sums = product.map do |arr|
#       arr.reduce(:+)
#     end
#     # If there's 2 Aces, we'll have more than 2 sums, but one will be a duplicate
#     #   and the the other will exceed 21, so we eliminate them here
#     sums.uniq.select { |item| item <= 21}
#     puts "sums: #{sums}"
#     value = "#{sums.min}/#{sums.max}"
#   else
#     # there's no ace so just sum up the face values of all the cards
#     puts "No ace here"
#     value = cards.reduce(0) { |sum, card| sum + card[:values][0] }
#   end
#   hand[:value] = value
#   # binding.pry
# end

def has_ace(hand) 
  ace_cards = hand[:cards].select {|card| card[:face] == "A"}
  return ace_cards.size > 0 
end

def players_turn(gd)
  # repeat until player stays or bust
  # player_tally = get_hand_value(gd, gd[:player])
  
  # puts "Card total: #{player_tally}"
  puts "Your call, #{gd[:player][:name]}."
  gd[:state] = :player_turn
  while true
    puts "\n[H]it or [S]tay"
    input = gets.chomp.downcase
    if input == "h" 
      hit(gd, gd[:player])  
    end
    break if input == "s"
  end
  stay(gd, gd[:player])
end

def hit(gd, which_player) 
  # deal another card to specified player
   deal_card(gd, which_player)
   draw(gd)
   sleep 1
end 

def stay(gd, which_player)
  puts "#{gd[:player][:name]} stays"
end

def draw(gd)
  system 'clear'
  lines = [] # strings to draw
  # add
  lines[0] = " #{gd[:player][:name]}#{SPACE * 10}"
  lines[1] = "#{HASH * 30}"
  lines[2] = "" #this is where we draw the card data
  lines[3] = "#{HASH * 30}"
  lines[4] = "" #card totals
  
  player_cards = gd[:player][:hand][:cards]
  dealer_cards = gd[:dealer][:hand][:cards]
  # add player cards
  if !player_cards.empty?
    player_cards.each do |card|
      lines[2] += "#{card[:face]}#{card[:symbol]}#{SPACE * 3}"
    end
    lines[4] += "#{gd[:player][:hand][:value]}"
  end
  
  # add dealer cards
  if !dealer_cards.empty?
    lines[0] += "| Dealer#{SPACE * 2}" # space after Player header
    lines[2] += "#{SPACE * 10}"
    dealer_cards.each do |card|
      # dealer's first card is initially face down. How do we handle that?
      card_string = card[:is_face_up] == true ? "#{card[:face]}#{card[:symbol]}" : "??" 
      lines[2] += "#{card_string}#{SPACE * 3}"
    end
    lines[4] += "#{SPACE * 10}#{gd[:dealer][:hand][:value]}"
 end
  # draw all lines
  lines.each { |line| puts line}
end

# ==================== PROGRAM START ====================
 
# deck is an array of cards
deck = make_deck
      
# game_data contains all data we need to pass between methods
game_data = { dealer: {name:'Dealer', hand: {cards: [], value:0}, wins:0, losses:0},
              player: {name:'Player', hand: {cards: [], value:0}, wins:0, losses:0},
              deck:   deck,
              state:  nil
            }
            
system 'clear'
puts "Tell me your name:"
game_data[:player][:name] = gets.chomp
puts "Welcome, #{game_data[:player][:name]}!"

# program loop
loop do
  game_over = false #maybe put this in reset method
  # game loop
  begin
    # shuffle deck
    
    # get player name
     
    # deal
    start_game(game_data)
    players_turn(game_data)
    dealers_turn(game_data)
    
    
    break # TEMP
  end while !game_over
  break # TEMP
end


