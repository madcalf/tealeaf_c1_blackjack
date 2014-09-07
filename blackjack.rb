# encoding: UTF-8

# Course 1. Lesson 1. Blackjack (procedural)

# The playing card Unicode symbols are copied from here:
#   http://en.wikipedia.org/wiki/Playing_cards_in_Unicode
#   Can also draw them using these unicode vaules:
#   ♧ = "\u2667", ♢ = "\u2662", ♡ = "\u2661", ♤ = "\u2664"
#   They're wider than normal chars so need to add space after them to avoid
#     overlapping.

require 'pry'

FACES = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
SUITS = [{'C' => "\u2667"}, {'D' => "\u2662"}, {'H' => "\u2661"}, {'S' => "\u2664"}]
# SUITS = [{'C' => '♧'}, {'D' => '♢'}, {'H' => '♡'}, {'S' => '♤'}]
DELAY = 1

# for drawing
SPACE =     " "
DASH = "-"

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

def unicode_supported?
  # test if unicode support is available 
  # found this test here: http://rosettacode.org/wiki/Terminal_control/Unicode_output#Ruby 
  ENV.values_at("LC_ALL","LC_CTYPE","LANG").compact.first.include?("UTF-8")
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
  # use the letter if unicode is not supported
  symb = unicode_supported? ? suit.values[0] : suit.keys[0]
  card = {face: face, suit: suit.keys[0], values:nil, symbol:symb, is_face_up: true}
  if numeric?(face)
    card[:values] = [face.to_i]
  else
    card[:values] = (face == 'A') ? [1, 11] : [10]
  end
  return card 
end

# If face is passed, it will deal a card with that face and optional suit
#   This allows testing of specific cards without waiting for them to happen randomly
def deal_card(gd, which_player, is_face_up = true, face = nil, suit = nil)
  # for test cards only
  if (face) 
    cards = gd[:deck].select { |card| card[:face] == face}
    # if no suit is specified, pick a random card with the specified face value
    if suit
      card = cards.select { |card| card[:suit] == suit}.sample
    else
      card = cards.sample
    end
  else # normal random card selection
    card = get_card(gd)
  end 

  card[:is_face_up] = is_face_up
  which_player[:hand][:cards].push(card)
  update_hand_value(gd, which_player)
  draw(gd)
end

def get_card(gd) 
  # need to remove card from deck
  card = gd[:deck].sample
  gd[:deck].delete(card)
end

def reset(gd)
  gd[:state] = :reset
  gd[:player][:hand] = {cards: [], value:0}
  gd[:dealer][:hand] = {cards: [], value:0}
  gd[:deck] = make_deck
  gd[:deck].shuffle
  0..4.times { |i| clear_message(gd, i)}
end

def start_game(gd)
  set_message(gd, 0, "Dealing...")
  sleep DELAY
  gd[:state] = :deal
  
  # deal player cards first
  2.times do 
    deal_card(gd, gd[:player])
    sleep DELAY
  end

  # dealer's cards
  # note: dealer's first card goes face down  
  2.times do |i|
    is_face_up = (i == 0) ? false : true
    deal_card(gd, gd[:dealer], is_face_up)
    sleep DELAY
  end
    
  # -------------- TEMP ---------------
  # for testing specific card combos without
  # waiting for them to randomly happen
  # -----------------------------------
  # player:
  # deal_card(gd, gd[:player], true, "A")
  # deal_card(gd, gd[:player], true, "A")
  # # deal_card(gd, gd[:player], true, "2")

  # dealer:
  # deal_card(gd, gd[:dealer], false, "J")
  # deal_card(gd, gd[:dealer], true, "A")
  # deal_card(gd, gd[:dealer], true, "2")
  # ------------------------------------
end

# calculates the current value(s) of the specified player's hand
#   if there's an Ace, this hand will have 2 values
def update_hand_value(gd, which_player)
  hand = which_player[:hand]
  cards = hand[:cards]
  if cards.size == 1
    # there's only one card so just get the face value or the max if it's an Ace
    value = cards[0][:values].max
  else
    # note if there's an ace, card[:values] will have 2 items: [1, 11] 
    #   otherwise it will have one: [9]
       
    # collect an array of all card values in this hand
    values = cards.map { |card| card[:values]}
    
    # get the cross product of the first card's value(s) & the remaining ones
    #   This turns multiple arrays from this [[10], [3], [4]] to this: [[10, 3, 4]]  
    #   With an Ace it goes from something like [[1, 11], [5], [3]] to this: [[1, 5, 3], [11, 5, 3]]
    #   note we need use the splat (*) so we pass the inner arrays as args
    product = values.first.product(*values.drop(1))
 
    # sum up the totals of each resulting array. 
    #   the result is an array of sums e.g. [8, 18]
    sums = product.map do |arr|
      arr.reduce(:+)
    end
 
    # If there's 2 Aces, we'll have more than 2 sums, but they'll be duplicates
    #   or will exceed 21, so we can eliminate all those here
    #   if they all exceed 21 we've busted so pick the minimum as the final sum
    if sums.size > 2
      if sums.all? { |item| item > 21}
        sums = [sums.min] 
      else
        sums = sums.uniq.select { |item| item <= 21}
      end
    end
    # when we have 2 sums (e.g. from a soft hand), drop the max if it exceeds 21
    if (sums.size == 2) 
      sums.delete sums.max if sums.max > 21
    end
  end
  hand[:value] = sums
end

def has_ace(hand) 
  ace_cards = hand[:cards].select {|card| card[:face] == "A"}
  return ace_cards.size > 0 
end

def players_turn(gd)
  clear_message(gd, 0)

  # repeat until player stays or busts   
  gd[:state] = :players_turn
  while true
    set_message(gd, 0, "Your call, #{gd[:player][:name]}.")
    set_message(gd, 1, "[H]it or [S]tay")
    input = gets.chomp.downcase
    if input == "h" 
      hit(gd, gd[:player])  
      if bust?(gd, gd[:player]) 
        end_game(gd)
        break
      end
    elsif input == "s"
      stay(gd, gd[:player])
      break
    end
  end
end

def dealers_turn(gd) 
  gd[:state] = :dealer_turn
  clear_message(gd, 2)
  show_dealer_cards(gd)
  
  # dealer must hit on anything under 17; must stay at 17.
  while true
    val = gd[:dealer][:hand][:value]
    if val.min < 17
      hit(gd, gd[:dealer])
      if bust?(gd, gd[:dealer])
        end_game(gd)
        break
      end
    elsif val.min.between?(17, 21)
      stay(gd, gd[:dealer])
      break
    end
  end
end

def show_dealer_cards(gd)
  down_cards = gd[:dealer][:hand][:cards].select { |card| card[:is_face_up] == false }
  down_cards.each { |card| card[:is_face_up] = true}
end

# returns true if either player has a blackjack
def test_for_blackjack(gd)
  return blackjack?(gd, gd[:player]) || blackjack?(gd, gd[:dealer])
end

# test specified player's hand for blackjack
# blackjack occurs only if player or dealer's initial 2 cards total 21
def blackjack?(gd, which_player)
  return which_player[:hand][:cards].size == 2 && which_player[:hand][:value].max == 21   
end

def bust?(gd, which_player)
  return which_player[:hand][:value].min > 21
end

# deal additional card to specified player
# note: face and suit args are only for testing specific cards
def hit(gd, which_player, face = nil, suit = nil) 
  line = which_player == gd[:dealer] ? 2 : 1
  set_message(gd, line, "#{which_player[:name]} hits.")
  if (face)
    deal_card(gd, which_player, true, face, suit)
  else
    deal_card(gd, which_player)
  end
  draw(gd)
  sleep DELAY
end 

def stay(gd, which_player)
  line = which_player == gd[:dealer] ? 2 : 1
  clear_message(gd, 0)
  score = get_final_score(gd, which_player)
  set_message(gd, line, "#{which_player[:name]} stays at #{score}.")
  draw(gd)
end

def get_final_score(gd, which_player)
  # if value has 2 scores (meaining an A is present), 
  #   this picks the most beneficial value for the specified player
  val = which_player[:hand][:value]
  score = (val.max > 21) ? val.min : val.max
  # update the value in gd for final display
  which_player[:hand][:value] = [score]
  return score
 end
  

def end_game(gd)
  gd[:state] = :game_over
  clear_message(gd, 0)
  
  # flip dealer's down card if it hasn't already been flipped
  show_dealer_cards(gd)
  
  player_score = get_final_score(gd, gd[:player])
  dealer_score = get_final_score(gd, gd[:dealer])
  
  dealer_has_blackjack = blackjack?(gd, gd[:dealer])
  player_has_blackjack = blackjack?(gd, gd[:player])
  
  set_message(gd, 1, "#{gd[:player][:name]} has a Blackjack!!") if player_has_blackjack
  set_message(gd, 2, "#{gd[:dealer][:name]} has a Blackjack!!") if dealer_has_blackjack
  
  if player_score > 21 
    set_message(gd, 1, "#{gd[:player][:name]} busts!")
    set_message(gd, 2, "#{gd[:dealer][:name]} WINS!!")
  elsif dealer_score > 21
    set_message(gd, 2, "#{gd[:dealer][:name]} busts!!")
    set_message(gd, 3, "#{gd[:player][:name]} WINS!!")    
  elsif player_score == dealer_score
    # NOTE: a 21 from a blackjack beats a normal 21
    if player_has_blackjack && !dealer_has_blackjack
      set_message(gd, 3, "#{gd[:player][:name]} WINS!!")    
    elsif dealer_has_blackjack && !player_has_blackjack
      set_message(gd, 3, "#{gd[:dealer][:name]} WINS!!")    
    else
      set_message(gd, 3, "PUSH (Player and Dealer tie)!")
    end
  elsif player_score > dealer_score
    set_message(gd, 3, "#{gd[:player][:name]} WINS!!")
  else
    set_message(gd, 3, "#{gd[:dealer][:name]} WINS!!")
  end
  draw(gd)
end

def set_message(gd, line, msg)
  gd[:messages][line] = msg
  draw(gd)
end

def clear_message(gd, line)
  gd[:messages][line] = ""
  draw(gd)
end

def draw(gd)
  system 'clear'
  player_cards = gd[:player][:hand][:cards]
  dealer_cards = gd[:dealer][:hand][:cards]
  
  player_header_str = " #{gd[:player][:name]}"
  dealer_header_str = "#{SPACE * 5}Dealer#{SPACE * 2}"
  player_card_str = ""
  player_value_str = ""
  dealer_card_str = ""
  dealer_value_str = ""
  
  # player cards
  if !player_cards.empty?
    player_cards.each do |card|
      player_card_str += "#{card[:face]}#{card[:symbol]}#{SPACE * 3}"
    end
    val = gd[:player][:hand][:value]
    if val
      player_value_str += val.size == 1 ? "#{val[0]}" : "#{val.min}/#{val.max}"
    end
  end
    
  # dealer cards
  if !dealer_cards.empty?
    dealer_cards.each do |card|
      card_string = card[:is_face_up] ? "#{card[:face]}#{card[:symbol]}" : "?" 
      dealer_card_str += "#{card_string}#{SPACE * 3}"
    end  
    # if it's dealer's initial hand and first card is down, summarize only the face up card.
    #   otherwise show full hand value. If less than 2 cards, do not show any value
    if dealer_cards.size > 1
      if !dealer_cards[0][:is_face_up]
        dealer_value_str = "Dealer shows a #{dealer_cards[1][:face]}"
      else
        val = gd[:dealer][:hand][:value]
        dealer_value_str = val.size == 1 ? "#{val[0]}" : "#{val.min}/#{val.max}"
      end
    end
 end
 
  # now draw it all
  draw_title
  puts "#{player_header_str.ljust(35)}#{dealer_header_str}"
  puts "#{DASH * 75}"
  puts "#{player_card_str.ljust(35)}|#{SPACE * 5}#{dealer_card_str}"
  puts "#{DASH * 75}"
  puts player_value_str.ljust(40) + dealer_value_str
  puts
  gd[:messages].each { |msg| puts "#{msg}"}
end

def draw_title(with_marquee = true)
  with_marquee ? chr = "*" : chr = " "
  puts
  puts "#{chr * 30}".center(75)
  puts "Tealeaf Casino Blackjack".center(75)
  puts "#{chr * 30}".center(75)
  puts
end

# ==================== PROGRAM START ====================

# deck is an array of cards. A card is a hash
deck = make_deck
      
# game_data contains all data we need to pass between methods
game_data = { dealer: {name:'Dealer', hand: {cards: [], value:0}},
              player: {name:'', hand: {cards: [], value:0}},
              deck:   deck,
              state:  nil,
              messages: []
            }

system 'clear'
# flash the marquee to start
5.times do
  chr = ' '
  system 'clear'
  draw_title(false)
  sleep 0.2
  system 'clear'
  draw_title(true)
  sleep 0.2
end

puts "Tell me your name:"
game_data[:player][:name] = gets.chomp.capitalize

# program loop
loop do
  # game loop
  begin
    start_game(game_data)
    
    # test for blackjacks after inital deal
    if test_for_blackjack(game_data)
      end_game(game_data) 
      break
    end
    
    players_turn(game_data)
    sleep DELAY
    
    # if player busts, instant loss. Otherwise dealer gets turn
    if game_data[:state] != :game_over
      dealers_turn(game_data)
    end
    
    end_game(game_data)
  end while game_data[:state] != :game_over

  puts "\nPlay again?  [Y]es  [N]o"
  if gets.chomp.downcase == "y" 
    reset(game_data)
  else 
    puts ("Thanks for playing, #{game_data[:player][:name]}!")
    break
  end
    
end   # program loop


