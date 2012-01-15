require '../lib/cabbage'

Cabbage.song do
  title "CABbAGE"
  by "Jeremy Ruten"

  tempo 100
  time 6..8

  instrument :vi, "Violin"
  instrument :vo, "Viola"
  instrument :ce, "Cello"

  3.times do |i|
    measure (i+1) do
      vi "+ c  a  bb a  g  e"
      vi "  f  f  g  f  e  g"
      vo "- a  c^ e^ f^ c^ c^"
      ce "- fv av c  f  e  c"
    end
  end

  measures 4..5 do
    vi "+ c  a  bb a  g  e  2.:f"
    vi "  f  f  g  f  e  g  2.:f"
    vo "- a  c^ e^ f^ c^ bb 2.:a"
    ce "- fv av c  f  e  c  2.:fv"
  end

  write "cabbage.mid"
end
