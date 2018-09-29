###
# File to associate names to valve numbers
#  as well as to keep track of avr. water output
#  and how long it takes to put 1" of water on
#  area covered by sprinkler. A rough 1" is the
#  recom. amount per week for a happy lawn.
#  The duration given here is in secoands and
#  1/2 the required amount, assuming the lawn
#  will be watered twice a week
#

# sprinklers=(hedge shed garage terrace ship)
# consumption=( 45 70 58 58 69 )
sprinklers=(ship terrace terrace2 shed garage hedge)
consumption=( 89 80 57 100 105 69 )
durations=( 480 1800 2280 1500 810 2000 )
# 0 Ship
# 1 Terrace
# 2 Terrace2
# 4 Garage
#  Avr water consumption:
#   ship 6.8-6.99 New: 8.85l/min
#   hedge 4.5
#   shed  7 new: 9.75l/min
#   Ter   5.8 new: 8.0
#   Gar new: 10.5
## New measurement:
# Ter2: 5.7l/min
# 
# Calcs:
#  Ter-Spr: ca. 20m^2 - 1" high uses 500l at 8l/min takes 62min per week
#  Ter2: ca. 18m^2 - 1" high uses 432l at 5.7l/min takes 76min
#  Shed: ca. 20m^2 - 1" high uses 500l at 10/min takes 50minutes
#  Ship: ca. 6m^2 - 1" high uses 144l at 8.9l/min takes 16min
#  Gara: ca 12m^2 - 1" high uses 288l at 10.5l/min takes 27min
