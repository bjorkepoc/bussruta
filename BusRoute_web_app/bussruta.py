# Først lage kortstokken
import itertools
import random

A, K, Q, J = 1 , 13 , 12 , 11
kort_tall = [ A , 2 , 3 , 4 , 5 , 6 , 7 , 8 , 9 , 10 , J , Q , K ]
# kort_tall = [ "A" , 2 , 3 , 4 , 5 , 6 , 7 , 8 , 9 , 10 , "J" , "Q" , "K" ]
C , D , H , S = "♣", "♦" , "♥" , "♠"
type = ["♣", "♦" , "♥" , "♠"] # Kløver, ruter , hjerter , spar
iterasjon = 0

spillere = []

stokk = []

def lag_kortstokk():
    stokk = list(itertools.product(type , kort_tall))
    print(stokk)
lag_kortstokk()

# spiller_1kort = spillere[0]
# spiller_2kort = spillere[1]
# spiller_3kort = spillere[2]
# spiller_4kort = spillere[3]

def start():
    global kort_stokk, spillere, spiller_kort
    kort_stokk = list(itertools.product(type , kort_tall))
    spiller_kort = []

# lage en måte man kan trekke kort, slik at de blir borte fra kortstokken
def trekk_kort():
    #Her skal man trekke kort, blir da fjernet fra kortstokken
    trekk = random.choice(kort_stokk)
    kort_stokk.remove(trekk)
    return trekk

# Skal slettes senere
def trekk():
    trekk = random.choice(kort_stokk)
    kort_stokk.remove(trekk)
    spiller_kort.append(trekk)
    return trekk



# Lage en meny for spillet
def spill():
    global iterasjon
    if iterasjon > 0:
        print("--- Restarter programmet ---")
        print(f"Spill nummer {iterasjon + 1 } starter nå")
    else:
        print("Velkommen til bussruta!")
        print('''
    ------------------- REGLER FOR SPILL AV BUSSRUTA -------------------

    Gjetter du riktig kan du dele ut slurker, om feil må du drikke selv.

    Runde 1: Gjett farge på kort, 1 slurk
    Runde 2: Gjett over eller under første kortet, 2 slurker
    Runde 3: Gjett mellom eller utenfor dine tidligere kort, 3 slurker
    Runde 4: Gjett hvilken sort du trekker, 4 slurker

            // Skriv: " spill() " om dere vil restarte spillet //
    --------------------------------------------------------------------
        ''')
    start()
    iterasjon += 1
    antall = int(input("Hvor mange er det som skal spille?: "))
    for i in range(antall):
        spillere.append(input(f"Navn på spiller: {i + 1}"))
    print(f"{len(spillere)} spillere")


# Spill nr 1, gjette om rødt eller svart
def rødt_svart():
    print('''--- Da starter vi med rødt eller svart. ---
          ''')

    for i in range (0 , len(spillere)):
        print(f"Det er nå {spillere[i]} sin tur")
        while True:
            gjett = input(f"{spillere[i]}, gjetter du rødt eller svart? ")
            if gjett == "svart" or gjett == "rødt":
                break
            else:
                print("Skriv inn en gyldig farge")
            
        trekk = trekk_kort()
        spiller_kort.append(trekk)

        print(f"Du trakk: {trekk}")

        if C in trekk or S in trekk:
            farge = "svart"
        elif H in trekk or D in trekk:
            farge = "rødt"
        if gjett.lower() == farge:
            print(f"Riktig, det ble {farge}! Del ut 1 slurk." )
        else:
            print(f"Feil, det ble {farge}... Du må drikke 1 slurk selv. ")


# Lage en måte man kan gjette hvilket kort man trekker
# Gjøre det mulig å se hvilke kort man har på hånden underveis