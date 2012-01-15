require '../lib/cabbage'

Cabbage.song do
  title "Salad"
  by "Jeremy Ruten"

  tempo 100
  time 6..4

  instrument :vi, "Violin"
  instrument :vo, "Viola"
  instrument :ce, "Cello"

  4.times do
    measure 1 do
      vi "+   c a bb a g e" # cabbage
      vi "    1:e f f c e", :default_note => 8 # lettuce
      vo "-   c b e e g e" # cheese
      ce "- - f a b a f a" # tomato
    end
  end

  measures 2..3 do
    vi "2.:f^ 4.:g^ 4.:f^ 1.:e^"
    vi "2.:c 2.:bv 1.:c"
    vo "2.:av 2.:gv 1.:gv"
    ce "2.:fvv 2.:evv 1.:cvv"
  end

  write "salad.mid"
end

